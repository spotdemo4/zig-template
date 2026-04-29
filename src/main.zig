const std = @import("std");
const zig_template = @import("zig_template");
const Init = std.process.Init;
const Io = std.Io;

pub fn main(init: Init) !void {
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});

    // Prints to stdout, propagating potential errors.
    var stdout = Io.File.stdout().writer(init.io, &.{});
    try stdout.interface.writeAll("Run `zig build test` to run the tests.\n");
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), smith: *std.testing.Smith) anyerror!void {
            _ = context;

            var buf: [64]u8 = undefined;
            const len: usize = @intCast(smith.slice(&buf));
            const input = buf[0..len];

            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
