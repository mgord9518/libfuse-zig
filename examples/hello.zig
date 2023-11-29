// HelloFS - minimal filesystem for example

const std = @import("std");
const fuse = @import("fuse");

const S = std.os.linux.S;

const file_contents = "Hello, world!\n";

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var args_it = std.process.args();

    const argv0 = args_it.next().?;

    const mount_dir = args_it.next() orelse {
        std.debug.print(
            "Usage: {s} [mountpoint]",
            .{argv0},
        );

        return;
    };

    try fuse.run(
        allocator,
        &[_][:0]const u8{
            argv0,
            mount_dir,
        },
        FuseOperations,
        void,
    );
}

const FuseOperations = struct {
    pub fn read(
        _: [:0]const u8,
        buf: []u8,
        _: u64,
        _: *fuse.FileInfo,
    ) fuse.MountError!usize {
        std.mem.copyForwards(u8, buf, file_contents);

        return file_contents.len;
    }

    pub fn readDir(
        _: [:0]const u8,
        filler: fuse.FillDir,
        _: *fuse.FileInfo,
        _: fuse.ReadDirFlags,
    ) fuse.MountError!void {
        try filler.add(".", null);
        try filler.add("..", null);

        try filler.add("hello", null);
    }

    pub fn getAttr(
        path: [:0]const u8,
        _: *fuse.FileInfo,
    ) fuse.MountError!std.os.Stat {
        var stat = std.mem.zeroes(std.os.Stat);

        if (std.mem.eql(u8, path, "/")) {
            stat.mode = 0o755 | S.IFDIR;
            stat.nlink = 2;
        } else {
            stat.mode = 0o444 | S.IFREG;
            stat.nlink = 1;
            stat.size = file_contents.len;
        }

        return stat;
    }
};
