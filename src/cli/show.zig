const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const action = @import("action.zig");
const fmt = @import("format.zig");
const parse = @import("parse.zig");

pub fn run(alloc: Allocator, args: *std.process.ArgIterator) !void {
    @setEvalBranchQuota(10000);
    _ = alloc;
    var out_buf: [8192]u8 = undefined;
    var out_w = std.fs.File.stdout().writer(&out_buf);
    const out = &out_w.interface;

    var opts = fmt.Options{};
    var color_str: ?[]const u8 = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))
            return action.ActionError.HelpRequested;
        if (std.mem.eql(u8, arg, "--json")) {
            opts.json = true;
        } else if (std.mem.eql(u8, arg, "--precision")) {
            const val = args.next() orelse return action.ActionError.HelpRequested;
            opts.precision = std.fmt.parseInt(u8, val, 10) catch return action.ActionError.HelpRequested;
        } else {
            color_str = arg;
        }
    }

    const input = try parse.parse(color_str orelse return action.ActionError.HelpRequested);

    if (opts.json) {
        try fmt.formatAllJson(input, opts, out);
        try out.writeAll("\n");
    } else {
        // Always show hex
        const srgb = lib.color.convert(input, .srgb).srgb;
        try out.print("  hex:                 #{X:0>6}\n", .{srgb.toHex()});

        inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
            const space: lib.Space = @enumFromInt(field.value);
            const cli_name = comptime fmt.spaceCliName(space);
            const result = lib.color.convert(input, space);
            try out.print("  {s}:", .{cli_name});
            const pad = 20 -| cli_name.len;
            for (0..pad) |_| try out.writeAll(" ");
            try out.writeAll("(");
            switch (result) {
                inline else => |c| try fmt.formatValues(c, opts, out),
            }
            try out.writeAll(")\n");
        }
    }
    try out.flush();
}
