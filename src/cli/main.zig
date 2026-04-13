const std = @import("std");
const lib = @import("libchroma");
const Action = @import("action.zig").Action;
const fmt = @import("format.zig");

pub fn main() u8 {
    run() catch |err| {
        var buf: [256]u8 = undefined;
        var w = std.fs.File.stderr().writer(&buf);
        const stderr = &w.interface;
        stderr.print("Error: {s}\n", .{@errorName(err)}) catch {};
        stderr.flush() catch {};
        return 1;
    };
    return 0;
}

fn run() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    _ = args.skip(); // program name

    const cmd = args.next();

    if (cmd == null) {
        printUsage(std.fs.File.stderr());
        return;
    }

    if (std.mem.eql(u8, cmd.?, "--help") or std.mem.eql(u8, cmd.?, "-h")) {
        printUsage(std.fs.File.stdout());
        return;
    }

    if (std.meta.stringToEnum(Action, cmd.?)) |action| {
        return action.run(alloc, &args);
    }

    printUsage(std.fs.File.stderr());
}

fn printUsage(file: std.fs.File) void {
    var buf: [4096]u8 = undefined;
    var w = file.writer(&buf);
    const out = &w.interface;
    out.print(
        \\Usage: chroma <command> [args]
        \\
        \\Commands:
        \\  convert <color> <space>   Convert a color to a target space
        \\  info <color>              Show a color in all spaces
        \\
        \\Color formats: #RRGGBB, RRGGBB, space(v1, v2, v3)
        \\
    , .{}) catch {};
    out.print("Spaces:\n", .{}) catch {};
    inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
        const space: lib.Space = @enumFromInt(field.value);
        out.print("  {s}\n", .{comptime fmt.spaceCliName(space)}) catch {};
    }
    out.flush() catch {};
}
