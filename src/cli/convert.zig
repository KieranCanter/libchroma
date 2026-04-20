const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const action = @import("action.zig");
const fmt = @import("format.zig");
const parse = @import("parse.zig");

/// Help text printed for the convert subcommand.
pub const help =
    \\Convert a color to a target color space.
    \\
    \\Usage: chroma convert <color> <space> [options]
    \\
    \\Options:
    \\  --precision N      Decimal places (default: 2)
    \\  --json             Output as JSON
    \\
    \\Color formats:
    \\  #RRGGBB            Hex with or without hash
    \\  rgb(r, g, b)       RGB with values 0-255 (auto-detected) or 0-1
    \\  space(v1, v2, v3)  Any supported color space
    \\
    \\Example:
    \\  chroma convert "#C86432" oklch
    \\  chroma convert "rgb(50, 150 250)" oklch --json
    \\  chroma convert "lab(0.2, 0.5, 0.7)" hsv --precision 4
    \\
;

/// Parse args and convert a color to the requested space, writing to stdout.
pub fn run(alloc: Allocator, io: std.Io, args: *std.process.Args.Iterator) !void {
    _ = alloc;
    var out_buf: [4096]u8 = undefined;
    var out_w = std.Io.File.stdout().writer(io, &out_buf);
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

    const result = lib.color.convert(input.color, space);

    if (opts.json) {
        try fmt.formatColorJson(result, input.alpha, opts, out);
    } else {
        try fmt.formatColor(result, opts, out);
        if (input.alpha) |a| {
            try out.writeAll(" / ");
            try fmt.formatFloat(a, opts.precision, out);
        }
    }
    try out.writeAll("\n");
    try out.flush();
}
