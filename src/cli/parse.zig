const std = @import("std");
const lib = @import("libchroma");
const fmt = @import("format.zig");

pub const ParseError = error{
    InvalidHexFormat,
    InvalidFuncFormat,
    InvalidFormat,
    InvalidValues,
    UnknownSpace,
};

pub const ParseResult = struct {
    color: lib.Color,
    alpha: ?f32 = null,
};

/// Parse a color string and return an AlphaColor (alpha defaults to 1.0).
pub fn parse(input: []const u8) !ParseResult {
    const s = std.mem.trim(u8, input, " \t");
    if (isHexLike(s)) return parseHex(s);
    if (std.mem.indexOfScalar(u8, s, '(') != null) return parseFunc(s);
    return ParseError.InvalidFormat;
}

fn isHexLike(s: []const u8) bool {
    if (s.len == 0) return false;
    if (s[0] == '#') return true;
    if (s.len == 6 or s.len == 8) {
        for (s) |c| {
            if (!std.ascii.isHex(c)) return false;
        }
        return true;
    }
    return false;
}

fn parseHex(s: []const u8) !ParseResult {
    const hex_str = if (s[0] == '#') s[1..] else s;
    if (hex_str.len == 6) {
        const srgb = try lib.Srgb(f32).initFromHexString(hex_str);
        return .{ .color = .{ .srgb = srgb } };
    }
    if (hex_str.len == 8) {
        const srgb = try lib.Srgb(f32).initFromHexString(hex_str[0..6]);
        const a_byte = std.fmt.parseInt(u8, hex_str[6..8], 16) catch return ParseError.InvalidHexFormat;
        return .{ .color = .{ .srgb = srgb }, .alpha = @as(f32, @floatFromInt(a_byte)) / 255.0 };
    }
    return ParseError.InvalidHexFormat;
}

fn parseFunc(s: []const u8) ParseError!ParseResult {
    const paren = std.mem.indexOfScalar(u8, s, '(') orelse return ParseError.InvalidFuncFormat;
    if (s.len == 0 or s[s.len - 1] != ')') return ParseError.InvalidFuncFormat;

    const name = s[0..paren];
    const inner = s[paren + 1 .. s.len - 1];

    var vals: [5]f32 = undefined;
    var count: usize = 0;
    var it = std.mem.splitAny(u8, inner, ", %");
    while (count < 5) {
        const v = nextFloat(&it) orelse break;
        vals[count] = v;
        count += 1;
    }
    if (count < 3) return ParseError.InvalidValues;

    const space = fmt.spaceFromCliName(name) orelse return ParseError.UnknownSpace;
    const expected = fieldCount(space);

    // Check if last value is alpha (one extra value beyond expected)
    var alpha: ?f32 = null;
    var color_count = count;
    if (count == expected + 1) {
        alpha = vals[expected];
        color_count = expected;
    }

    // Auto-detect u8 sRGB: if space is srgb and any value > 1, treat as 0-255
    if (space == .srgb and color_count == 3 and (vals[0] > 1 or vals[1] > 1 or vals[2] > 1)) {
        return .{ .color = .{ .srgb = lib.Srgb(f32).init(vals[0] / 255.0, vals[1] / 255.0, vals[2] / 255.0) }, .alpha = alpha };
    }

    const c = lib.color.initFromSlice(space, vals[0..color_count]) catch return ParseError.InvalidValues;
    return .{ .color = c, .alpha = alpha };
}

fn fieldCount(space: lib.Space) usize {
    const fields = @typeInfo(lib.Color).@"union".fields;
    return switch (space) {
        inline else => |tag| @typeInfo(fields[@intFromEnum(tag)].type).@"struct".fields.len,
    };
}

fn nextFloat(it: anytype) ?f32 {
    while (it.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, " \t");
        if (trimmed.len == 0) continue;
        return std.fmt.parseFloat(f32, trimmed) catch return null;
    }
    return null;
}
