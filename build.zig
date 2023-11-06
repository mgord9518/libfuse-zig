const std = @import("std");
const builtin = @import("builtin");

pub fn build(b: *std.build.Builder) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "hello",
        .root_source_file = .{ .path = "examples/hello.zig" },
        .target = target,
        .optimize = optimize,
    });

    exe.target = target;
    exe.optimize = optimize;
    exe.addModule("fuse", module(b, .{}));

    link(exe, .{});

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

pub inline fn thisDir() []const u8 {
    return comptime std.fs.path.dirname(@src().file) orelse unreachable;
}

pub const LinkOptions = struct {
    use_system_fuse: bool = false,
    fusermount_dir: []const u8 = "/usr/local/bin",
};

pub fn module(b: *std.Build, opts: LinkOptions) *std.Build.Module {
    _ = opts;
    const prefix = thisDir();

    return b.createModule(.{
        .source_file = .{ .path = prefix ++ "/lib.zig" },
    });
}

pub fn link(exe: *std.Build.Step.Compile, opts: LinkOptions) void {
    const prefix = thisDir();

    // The directory must be surrounded by quotes so that the C
    // preprocessor will substitute it as a string literal
    const quoted_fusermount_dir = std.fmt.allocPrint(
        exe.step.owner.allocator,
        "\"{s}\"",
        .{opts.fusermount_dir},
    ) catch {
        @panic("OOM");
    };

    if (opts.use_system_fuse) {
        exe.linkSystemLibrary("fuse3");
    } else {
        const libfuse_dep = exe.step.owner.dependency("libfuse", .{
            .target = exe.target,
            .optimize = exe.optimize,
        });

        exe.addIncludePath(libfuse_dep.path("include"));
        exe.addIncludePath(.{ .path = prefix ++ "/libfuse_config" });

        // TODO: configurable build opts
        exe.defineCMacro("FUSERMOUNT_DIR", quoted_fusermount_dir);
        exe.defineCMacro("_REENTRANT", null);
        exe.defineCMacro("HAVE_LIBFUSE_PRIVATE_CONFIG_H", null);
        exe.defineCMacro("_FILE_OFFSET_BITS", "64");
        exe.defineCMacro("FUSE_USE_VERSION", "312");

        exe.defineCMacro("HAVE_COPY_FILE_RANGE", null);
        exe.defineCMacro("HAVE_FALLOCATE", null);
        exe.defineCMacro("HAVE_FDATASYNC", null);
        exe.defineCMacro("HAVE_FORK", null);
        exe.defineCMacro("HAVE_FSTATAT", null);
        exe.defineCMacro("HAVE_ICONV", null);
        exe.defineCMacro("HAVE_OPENAT", null);
        exe.defineCMacro("HAVE_PIPE2", null);
        exe.defineCMacro("HAVE_POSIX_FALLOCATE", null);
        exe.defineCMacro("HAVE_READLINKAT", null);
        exe.defineCMacro("HAVE_SETXATTR", null);
        exe.defineCMacro("HAVE_SPLICE", null);
        exe.defineCMacro("HAVE_STRUCT_ST_STAT_ST_ATIM", null);
        exe.defineCMacro("HAVE_UTIMENSAT", null);
        exe.defineCMacro("HAVE_VMSPLICE", null);
        exe.defineCMacro("PACKAGE_VERSION", "\"3.14.1\"");

        exe.defineCMacro("LIBFUSE_BUILT_WITH_VERSIONED_SYMBOLS", "1");

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
            exe.addCSourceFile(.{
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

                    "-fPIC",
                },
            });
        }
    }

    exe.linkLibC();
}
