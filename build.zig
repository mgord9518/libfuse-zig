const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const static = b.option(
        bool,
        "static",
        "build static, more portable but larger file size (default: true)",
    ) orelse true;

    //    const fusermount_dir = b.option(
    //        []const u8,
    //        "fusermount_dir",
    //        "The directory to search for fusermount on the host system",
    //    ) orelse "/usr/local/bin";

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = .{ .path = "examples/hello.zig" },
        .target = target,
        .optimize = optimize,
    });

    //    const lib = b.addStaticLibrary(.{
    //        .name = "fuse",
    //        .root_source_file = .{ .path = "lib.zig" },
    //        .target = target,
    //        .optimize = optimize,
    //    });

    const opts = b.addOptions();
    opts.addOption(bool, "static", static);
    //opts.addOption([]const u8, "fusermount_dir", fusermount_dir);

    const fuse_module = b.addModule("fuse", .{
        .root_source_file = .{
            .path = b.pathFromRoot("lib.zig"),
        },
        .imports = &.{.{
            .name = "build_options",
            .module = opts.createModule(),
        }},
    });

    if (static) {
        const lib = buildLibfuse(b, .{
            .name = "fuse",
            .target = target,
            .optimize = optimize,
        });

        b.installArtifact(lib);
        exe.linkLibrary(lib);
    } else {
        exe.linkSystemLibrary("fuse3");
    }

    //lib.linkLibC();

    exe.root_module.addImport("fuse", fuse_module);

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub fn buildLibfuse(
    b: *std.Build,
    options: std.Build.ExecutableOptions,
) *std.Build.Step.Compile {
    const libfuse = b.addStaticLibrary(.{
        .name = "fuse",
        .target = options.target,
        .optimize = options.optimize,
    });

    // TODO
    // The directory must be surrounded by quotes so that the C
    // preprocessor will substitute it as a string literal
    //    const quoted_fusermount_dir = try std.fmt.allocPrint(
    //        b.allocator,
    //        "\"{s}\"",
    //        .{fusermount_dir},
    //    );
    //    defer b.allocator.free(quoted_fusermount_dir);
    const quoted_fusermount_dir = "\"/usr/local/bin\"";

    const libfuse_dep = b.dependency("libfuse", .{
        .target = options.target,
        .optimize = options.optimize,
    });

    libfuse.root_module.addIncludePath(libfuse_dep.path("include"));
    libfuse.root_module.addIncludePath(.{ .path = b.pathFromRoot("libfuse_config") });

    // TODO: configurable build opts
    inline for (.{
        .{ "FUSERMOUNT_DIR", quoted_fusermount_dir },
        .{ "_REENTRANT", "" },
        .{ "FUSE_USE_VERSION", "312" },
        .{ "_FILE_OFFSET_BITS", "64" },
        .{ "HAVE_COPY_FILE_RANGE", "" },
        .{ "HAVE_FALLOCATE", "" },
        .{ "HAVE_FDATASYNC", "" },
        .{ "HAVE_FORK", "" },
        .{ "HAVE_FSTATAT", "" },
        .{ "HAVE_ICONV", "" },
        .{ "HAVE_OPENAT", "" },
        .{ "HAVE_PIPE2", "" },
        .{ "HAVE_POSIX_FALLOCATE", "" },
        .{ "HAVE_READLINKAT", "" },
        .{ "HAVE_SETXATTR", "" },
        .{ "HAVE_SPLICE", "" },
        .{ "HAVE_STRUCT_ST_STAT_ST_ATIM", "" },
        .{ "HAVE_UTIMENSAT", "" },
        .{ "HAVE_VMSPLICE", "" },
        .{ "PACKAGE_VERSION", "\"3.14.1\"" },
    }) |macro| {
        libfuse.root_module.addCMacro(
            macro[0],
            macro[1],
        );
    }

    if (options.target.result.abi == .gnu) {
        libfuse.root_module.addCMacro(
            "LIBFUSE_BUILT_WITH_VERSIONED_SYMBOLS",
            "1",
        );
    }

    libfuse.root_module.addCSourceFiles(.{
        .root = libfuse_dep.path("."),
        .files = &.{
            "lib/fuse_loop.c",
            "lib/fuse_lowlevel.c",
            "lib/fuse_opt.c",
            "lib/fuse_signals.c",
            "lib/buffer.c",
            "lib/compat.c",
            "lib/fuse.c",
            "lib/fuse_log.c",
            "lib/fuse_loop_mt.c",
            "lib/mount.c",
            //"lib/mount_bsd.c",
            "lib/mount_util.c",
            "lib/modules/iconv.c",
            "lib/modules/subdir.c",
            "lib/helper.c",
            "lib/cuse_lowlevel.c",
        },
    });

    libfuse.linkLibC();

    return libfuse;
}
