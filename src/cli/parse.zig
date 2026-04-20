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

/// Parse a color string into a Color with optional alpha.
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

// Tests

const testing = std.testing;

test "parse hex 6-char with #" {
    const r = try parse("#C86432");
    try testing.expectEqual(.srgb, std.meta.activeTag(r.color));
    try testing.expectApproxEqAbs(@as(f32, 0.784), r.color.srgb.r, 0.002);
    try testing.expectEqual(@as(?f32, null), r.alpha);
}

test "parse hex 6-char without #" {
    const r = try parse("C86432");
    try testing.expectEqual(.srgb, std.meta.activeTag(r.color));
}

test "parse hex 8-char with alpha" {
    const r = try parse("#C8643280");
    try testing.expectApproxEqAbs(@as(f32, 0.784), r.color.srgb.r, 0.002);
    try testing.expectApproxEqAbs(@as(f32, 0.502), r.alpha.?, 0.002);
}

test "parse functional srgb float" {
    const r = try parse("srgb(0.5, 0.3, 0.1)");
    try testing.expectEqual(.srgb, std.meta.activeTag(r.color));
    try testing.expectApproxEqAbs(@as(f32, 0.5), r.color.srgb.r, 0.001);
}

test "parse functional srgb u8 auto-detect" {
    const r = try parse("srgb(200, 100, 50)");
    try testing.expectApproxEqAbs(@as(f32, 0.784), r.color.srgb.r, 0.002);
}

test "parse functional rgb alias" {
    const r = try parse("rgb(200, 100, 50)");
    try testing.expectEqual(.srgb, std.meta.activeTag(r.color));
}

test "parse functional oklch" {
    const r = try parse("oklch(0.61, 0.14, 45)");
    try testing.expectEqual(.oklch, std.meta.activeTag(r.color));
    try testing.expectApproxEqAbs(@as(f32, 0.61), r.color.oklch.l, 0.001);
}

test "parse functional with alpha" {
    const r = try parse("oklch(0.61, 0.14, 45, 0.5)");
    try testing.expectApproxEqAbs(@as(f32, 0.5), r.alpha.?, 0.001);
}

test "parse functional cmyk (4 values)" {
    const r = try parse("cmyk(0.1, 0.2, 0.3, 0.4)");
    try testing.expectEqual(.cmyk, std.meta.activeTag(r.color));
    try testing.expectApproxEqAbs(@as(f32, 0.4), r.color.cmyk.k, 0.001);
}

test "parse functional cmyk with alpha (5 values)" {
    const r = try parse("cmyk(0.1, 0.2, 0.3, 0.4, 0.8)");
    try testing.expectApproxEqAbs(@as(f32, 0.8), r.alpha.?, 0.001);
}

test "parse space aliases" {
    try testing.expectEqual(.cie_xyz, std.meta.activeTag((try parse("xyz(0.5, 0.5, 0.5)")).color));
    try testing.expectEqual(.cie_lab, std.meta.activeTag((try parse("lab(50, 20, -30)")).color));
    try testing.expectEqual(.cie_lch, std.meta.activeTag((try parse("lch(50, 30, 180)")).color));
    try testing.expectEqual(.cie_yxy, std.meta.activeTag((try parse("yxy(0.5, 0.3, 0.3)")).color));
}

test "parse invalid format" {
    try testing.expectError(ParseError.InvalidFormat, parse("not a color"));
}

test "parse invalid hex length" {
    try testing.expectError(ParseError.InvalidHexFormat, parse("#ABC"));
}

test "parse unknown space" {
    try testing.expectError(ParseError.UnknownSpace, parse("fakespace(1, 2, 3)"));
}

test "parse too few values" {
    try testing.expectError(ParseError.InvalidValues, parse("srgb(0.5, 0.3)"));
}

test "parse trims whitespace" {
    const r = try parse("  #C86432  ");
    try testing.expectEqual(.srgb, std.meta.activeTag(r.color));
}

test "parse missing closing paren" {
    try testing.expectError(ParseError.InvalidFuncFormat, parse("srgb(0.5, 0.3, 0.1"));
}
