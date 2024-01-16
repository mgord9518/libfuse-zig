const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const libfuse_dep = b.dependency("libfuse", .{
        .target = target,
        .optimize = optimize,
    });

    const fuse_module = b.addModule(
        "fuse",
        .{ .root_source_file = .{ .path = b.pathFromRoot("lib.zig") } },
    );

    _ = b.addModule(
        "libfuse",
        .{ .root_source_file = libfuse_dep.path("lib.zig") },
    );

    const use_system_fuse = b.option(
        bool,
        "use-system-fuse",
        "use system FUSE3 library instead of vendored (default: false)",
    ) orelse false;

    const fusermount_dir = b.option(
        []const u8,
        "fusermount_dir",
        "The directory to search for fusermount on the host system",
    ) orelse "/usr/local/bin";

    const lib = b.addStaticLibrary(.{
        .name = "fuse",
        .root_source_file = .{ .path = "lib.zig" },
        .target = target,
        .optimize = optimize,
    });

    const opts = b.addOptions();
    opts.addOption(bool, "use_system_fuse", use_system_fuse);
    opts.addOption([]const u8, "fusermount_dir", fusermount_dir);

    // The directory must be surrounded by quotes so that the C
    // preprocessor will substitute it as a string literal
    const quoted_fusermount_dir = try std.fmt.allocPrint(
        b.allocator,
        "\"{s}\"",
        .{fusermount_dir},
    );
    defer b.allocator.free(quoted_fusermount_dir);

    if (use_system_fuse) {
        lib.linkSystemLibrary("fuse3");
    } else {
        lib.addIncludePath(libfuse_dep.path("include"));
        lib.addIncludePath(.{ .path = b.pathFromRoot("libfuse_config") });

        // TODO: configurable build opts
        lib.defineCMacro("FUSERMOUNT_DIR", quoted_fusermount_dir);
        lib.defineCMacro("_REENTRANT", null);
        lib.defineCMacro("FUSE_USE_VERSION", "312");
        lib.defineCMacro("_FILE_OFFSET_BITS", "64");

        lib.defineCMacro("HAVE_COPY_FILE_RANGE", null);
        lib.defineCMacro("HAVE_FALLOCATE", null);
        lib.defineCMacro("HAVE_FDATASYNC", null);
        lib.defineCMacro("HAVE_FORK", null);
        lib.defineCMacro("HAVE_FSTATAT", null);
        lib.defineCMacro("HAVE_ICONV", null);
        lib.defineCMacro("HAVE_OPENAT", null);
        lib.defineCMacro("HAVE_PIPE2", null);
        lib.defineCMacro("HAVE_POSIX_FALLOCATE", null);
        lib.defineCMacro("HAVE_READLINKAT", null);
        lib.defineCMacro("HAVE_SETXATTR", null);
        lib.defineCMacro("HAVE_SPLICE", null);
        lib.defineCMacro("HAVE_STRUCT_ST_STAT_ST_ATIM", null);
        lib.defineCMacro("HAVE_UTIMENSAT", null);
        lib.defineCMacro("HAVE_VMSPLICE", null);
        lib.defineCMacro("PACKAGE_VERSION", "\"3.14.1\"");

        lib.defineCMacro("LIBFUSE_BUILT_WITH_VERSIONED_SYMBOLS", "1");

        const c_files = &[_][]const u8{
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
            "lib/mount_util.c",
            "lib/modules/iconv.c",
            "lib/modules/subdir.c",
            "lib/helper.c",
            "lib/cuse_lowlevel.c",
        };

        for (c_files) |c_file| {
            lib.addCSourceFile(.{
                .file = libfuse_dep.path(c_file),
                .flags = &[_][]const u8{
                    "-Wall",
                    "-Winvalid-pch",
                    "-Wextra",
                    "-Wno-sign-compare",
                    "-Wstrict-prototypes",
                    "-Wmissing-declarations",
                    "-Wwrite-strings",
                    "-Wno-strict-aliasing",
                    "-Wno-unused-result",
                    "-Wint-conversion",

                    //"-fPIC",
                },
            });
        }
    }

    lib.linkLibC();

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = .{ .path = "examples/hello.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("fuse", fuse_module);

    exe.linkLibrary(lib);

    b.installArtifact(exe);
    b.installArtifact(lib);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
