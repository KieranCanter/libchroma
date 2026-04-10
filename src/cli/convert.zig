const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const action = @import("action.zig");
const fmt = @import("format.zig");
const parse = @import("parse.zig");

pub fn run(alloc: Allocator, args: *std.process.ArgIterator) !void {
    _ = alloc;
    var out_buf: [4096]u8 = undefined;
    var out_w = std.fs.File.stdout().writer(&out_buf);
    const out = &out_w.interface;

    var opts = fmt.Options{};
    var color_str: ?[]const u8 = null;
    var space_str: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))
            return action.ActionError.HelpRequested;
        if (std.mem.eql(u8, arg, "--json")) {
            opts.json = true;
        } else if (std.mem.eql(u8, arg, "--precision")) {
            const val = args.next() orelse return action.ActionError.HelpRequested;
            opts.precision = std.fmt.parseInt(u8, val, 10) catch return action.ActionError.HelpRequested;
        } else if (color_str == null) {
            color_str = arg;
        } else {
            space_str = arg;
        }
    }

    const input = try parse.parse(color_str orelse return action.ActionError.HelpRequested);
    const space = fmt.spaceFromCliName(space_str orelse return action.ActionError.HelpRequested) orelse return parse.ParseError.UnknownSpace;

    const result = lib.color.convert(input, space);

    if (opts.json) {
        try fmt.formatColorJson(result, opts, out);
    } else {
        try fmt.formatColor(result, opts, out);
    }
    try out.writeAll("\n");
    try out.flush();
}
