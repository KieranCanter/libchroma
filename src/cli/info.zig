const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const action = @import("action.zig");
const fmt = @import("format.zig");
const parse = @import("parse.zig");

const SpaceSet = std.EnumSet(lib.Space);

const FilterMode = enum { none, show, hide };

/// Help text printed for the info subcommand.
pub const help =
    \\Show a color in all supported color spaces.
    \\
    \\Usage: chroma info <color> [options]
    \\
    \\Options:
    \\  --precision N      Decimal places (default: 2)
    \\  --json             Output as JSON
    \\  --show <spaces>    Only show these color spaces
    \\  --hide <spaces>    Show all except these color spaces
    \\
    \\Color formats:
    \\  #RRGGBB            Hex with hash
    \\  RRGGBB             Hex without hash
    \\  rgb(r, g, b)       RGB with values 0-255 (auto-detected) or 0-1
    \\  space(v1, v2, v3)  Any supported color space
    \\
    \\Example:
    \\  chroma info "#C86432"
    \\  chroma info "#C86432" --json --precision 4
    \\  chroma info "#C86432" --show srgb oklch lab
    \\  chroma info "#C86432" --hide cmyk hsi
    \\
;

/// Parse args and display a color in all (or filtered) spaces to stdout.
pub fn run(alloc: Allocator, io: std.Io, args: *std.process.Args.Iterator) !void {
    @setEvalBranchQuota(10_000);
    _ = alloc;
    var out_buf: [8192]u8 = undefined;
    var out_w = std.Io.File.stdout().writer(io, &out_buf);
    const out = &out_w.interface;

    var opts = fmt.Options{};
    var color_str: ?[]const u8 = null;
    var filter_mode: FilterMode = .none;
    var filter_set = SpaceSet.initEmpty();

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h"))
            return action.ActionError.HelpRequested;
        if (std.mem.eql(u8, arg, "--json")) {
            opts.json = true;
        } else if (std.mem.eql(u8, arg, "--precision")) {
            const val = args.next() orelse return action.ActionError.HelpRequested;
            opts.precision = std.fmt.parseInt(u8, val, 10) catch return action.ActionError.HelpRequested;
        } else if (std.mem.eql(u8, arg, "--show")) {
            if (filter_mode == .hide) return action.ActionError.HelpRequested;
            filter_mode = .show;
        } else if (std.mem.eql(u8, arg, "--hide")) {
            if (filter_mode == .show) return action.ActionError.HelpRequested;
            filter_mode = .hide;
        } else if (fmt.spaceFromCliName(arg)) |space| {
            // Bare space name, only valid after --show or --hide
            if (filter_mode == .none) return action.ActionError.HelpRequested;
            filter_set.insert(space);
        } else {
            color_str = arg;
        }
    }

    // Validate: --show/--hide must have at least one space
    if (filter_mode != .none and filter_set.count() == 0)
        return action.ActionError.HelpRequested;

    const show_set = switch (filter_mode) {
        .none => SpaceSet.initFull(),
        .show => filter_set,
        .hide => SpaceSet.initFull().differenceWith(filter_set),
    };

    const input = try parse.parse(color_str orelse return action.ActionError.HelpRequested);

    if (opts.json) {
        try fmt.formatFilteredJson(input.color, input.alpha, show_set, opts, out);
        try out.writeAll("\n");
    } else {
        if (input.alpha) |a| {
            try out.print("  alpha:               ", .{});
            try fmt.formatFloat(a, opts.precision, out);
            try out.writeAll("\n");
        }

        if (show_set.contains(.srgb)) {
            const srgb = lib.color.convert(input.color, .srgb).srgb;
            try out.print("  hex:                 #{X:0>6}\n", .{srgb.toHex()});
        }

        inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
            const space: lib.Space = @enumFromInt(field.value);
            if (show_set.contains(space)) {
                const cli_name = comptime fmt.spaceCliName(space);
                const result = lib.color.convert(input.color, space);
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
    }
    try out.flush();
}
