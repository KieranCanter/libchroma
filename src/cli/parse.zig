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

/// Parse a color string and return a Color.
pub fn parse(input: []const u8) !lib.Color {
    const s = std.mem.trim(u8, input, " \t");
    if (isHexLike(s)) return parseHex(s);
    if (std.mem.indexOfScalar(u8, s, '(') != null) return parseFunc(s);
    return ParseError.InvalidFormat;
}

fn isHexLike(s: []const u8) bool {
    if (s.len == 0) return false;
    if (s[0] == '#') return true;
    if (s.len == 6) {
        for (s) |c| {
            if (!std.ascii.isHex(c)) return false;
        }
        return true;
    }
    return false;
}

fn parseHex(s: []const u8) !lib.Color {
    const hex_str = if (s[0] == '#') s[1..] else s;
    if (hex_str.len != 6) return ParseError.InvalidHexFormat;
    const srgb = try lib.Srgb(f32).initFromHexString(hex_str);
    return .{ .srgb = srgb };
}

fn parseFunc(s: []const u8) ParseError!lib.Color {
    const paren = std.mem.indexOfScalar(u8, s, '(') orelse return ParseError.InvalidFuncFormat;
    if (s.len == 0 or s[s.len - 1] != ')') return ParseError.InvalidFuncFormat;

    const name = s[0..paren];
    const inner = s[paren + 1 .. s.len - 1];

    var vals: [4]f32 = undefined;
    var count: usize = 0;
    var it = std.mem.splitAny(u8, inner, ", %");
    while (count < 4) {
        const v = nextFloat(&it) orelse break;
        vals[count] = v;
        count += 1;
    }
    if (count < 3) return ParseError.InvalidValues;

    // Auto-detect u8 sRGB: if space is srgb and any value > 1, treat as 0-255
    const space = fmt.spaceFromCliName(name) orelse return ParseError.UnknownSpace;
    if (space == .srgb and count == 3 and (vals[0] > 1 or vals[1] > 1 or vals[2] > 1)) {
        return .{ .srgb = lib.Srgb(f32).init(vals[0] / 255.0, vals[1] / 255.0, vals[2] / 255.0) };
    }

    return lib.color.initFromSlice(space, vals[0..count]) catch return ParseError.InvalidValues;
}

fn nextFloat(it: anytype) ?f32 {
    while (it.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, " \t");
        if (trimmed.len == 0) continue;
        return std.fmt.parseFloat(f32, trimmed) catch return null;
    }
    return null;
}
