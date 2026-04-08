const std = @import("std");
const Allocator = std.mem.Allocator;
const action = @import("action.zig");
const parse = @import("parse.zig");
const SpaceArg = @import("space_arg.zig").SpaceArg;

pub fn run(alloc: Allocator, args: *std.process.ArgIterator) !void {
    _ = alloc;
    var out_buf: [4096]u8 = undefined;
    var out_w = std.fs.File.stdout().writer(&out_buf);
    const out = &out_w.interface;

    const cmd = try parse.parseCommandArgs(args) orelse return action.ActionError.HelpRequested;

    inline for (@typeInfo(SpaceArg).@"enum".fields) |field| {
        const space: SpaceArg = @enumFromInt(field.value);
        try out.print("  {s}: ", .{field.name});
        const name_len: usize = field.name.len;
        var pad = @as(usize, 18) -| name_len;
        while (pad > 0) : (pad -= 1) try out.print(" ", .{});
        try space.print(out, cmd.xyz);
    }
    try out.flush();
}
