const std = @import("std");
const validation = @import("../validation.zig");
const color_formatter = @import("../color_formatter.zig");
const rgbToFloatType = validation.rgbToFloatType;

pub const srgb = @import("rgb/srgb.zig");
pub const p3 = @import("rgb/p3.zig");
pub const rec2020 = @import("rgb/rec2020.zig");

const Cmyk = @import("cmyk.zig").Cmyk;
const Hsi = @import("hsi.zig").Hsi;
const Hsl = @import("hsl.zig").Hsl;
const Hsv = @import("hsv.zig").Hsv;
const Hwb = @import("hwb.zig").Hwb;
const Srgb = srgb.Srgb;
const Xyz = @import("xyz.zig").Xyz;

pub const RgbError = error{
    InvalidHexString,
};

/// Type to hold a 24-bit Hex RGB value of three bytes (equivalent to an sRGB value). Effectively a convenience
/// wrapper for an Srgb(u8) represented as a u24, merging the red, green, and blue u8s together,
/// allowing those working with hex codes to pass the hexidecimal number as an integer or string to
/// initialize an RGB value.
///
/// value: RRGGBB value as a 3-byte (24-bit) unsigned integer
pub const HexRgb = struct {
    const Self = @This();

    value: u24,

    pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
        return color_formatter.ColorFormatter(Self).init(self, style);
    }

    pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("({x})", .{self.value});
    }

    pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("HexRgb(#{X})", .{self.value});
    }

    fn parseHexU8(r: u8, g: u8, b: u8) u24 {
        const byte0 = @as(u24, @intCast(r)) << 16;
        const byte1 = @as(u16, @intCast(g)) << 8;
        const byte2 = b;
        return byte0 | byte1 | byte2;
    }

    fn parseNibble(char: u8) RgbError!u8 {
        return switch (char) {
            '0'...'9' => char - '0',
            'a'...'f' => char - 'a' + 10,
            'A'...'F' => char - 'A' + 10,
            else => return RgbError.InvalidHexString,
        };
    }

    fn parseByte(byte: []const u8) RgbError!u8 {
        const nib_left = try parseNibble(byte[0]) << 4;
        const nib_right = try parseNibble(byte[1]);
        return nib_left | nib_right;
    }

    fn parseHexString(hex: anytype) RgbError!u24 {
        const hex_str: []const u8 = hex;

        if (hex_str.len == 7 and hex_str[0] == '#') {
            return parseHexString(hex_str[1..]);
        }

        if (hex_str.len != 6) {
            return RgbError.InvalidHexString;
        }

        const byte0: u24 = @as(u24, @intCast(try parseByte(hex_str[0..2]))) << 16;
        const byte1: u24 = @as(u16, @intCast(try parseByte(hex_str[2..4]))) << 8;
        const byte2: u24 = try parseByte(hex_str[4..6]);

        return byte0 | byte1 | byte2;
    }

    pub fn initFromU8(r: u8, g: u8, b: u8) Self {
        return .{ .value = parseHexU8(r, g, b) };
    }

    pub fn initFromU24(hex: u24) Self {
        return .{ .value = hex };
    }

    pub fn initFromString(hex: []const u8) RgbError!Self {
        const rgb = try parseHexString(hex);
        return .{ .value = rgb };
    }

    pub fn initFromSrgb(srgb_val: anytype) Self {
        const T = @TypeOf(srgb_val).Backing;
        if (T == u8) return .{ .value = parseHexU8(srgb_val.r, srgb_val.g, srgb_val.b) };

        const r = @as(u8, @intFromFloat(@round(srgb_val.r * 255.0)));
        const g = @as(u8, @intFromFloat(@round(srgb_val.g * 255.0)));
        const b = @as(u8, @intFromFloat(@round(srgb_val.b * 255.0)));
        return .{ .value = parseHexU8(r, g, b) };
    }

    pub fn toXyz(self: Self, comptime T: type) Xyz(T) {
        return self.toSrgb(T).toXyz();
    }

    pub fn fromXyz(xyz: anytype) Self {
        const T = @TypeOf(xyz).Backing;
        return initFromSrgb(Srgb(T).fromXyz(xyz));
    }

    pub inline fn toSrgb(self: Self, comptime T: type) Srgb(T) {
        const r: u8 = @as(u8, @intCast(self.value >> 16 & 0xFF));
        const g: u8 = @as(u8, @intCast(self.value >> 8 & 0xFF));
        const b: u8 = @as(u8, @intCast(self.value & 0xFF));

        if (T == u8) {
            return Srgb(u8).init(r, g, b);
        }

        return Srgb(T).init(
            @as(T, @floatFromInt(r)) / 255.0,
            @as(T, @floatFromInt(g)) / 255.0,
            @as(T, @floatFromInt(b)) / 255.0,
        );
    }
};

// Formula for sRGB -> CMYK conversion:
// https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
pub fn toCmyk(rgb: anytype) Cmyk(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(rgb.r, F);
    const g = rgbCast(rgb.g, F);
    const b = rgbCast(rgb.b, F);

    const k = 1.0 - @max(r, g, b);
    if (k == 1.0) { // Avoid division by 0
        return Cmyk(F).init(0, 0, 0, k);
    }
    const c = (1.0 - r - k) / (1.0 - k);
    const m = (1.0 - g - k) / (1.0 - k);
    const y = (1.0 - b - k) / (1.0 - k);

    return Cmyk(F).init(c, m, y, k);
}

// Formula for sRGB -> HSI conversion:
// https://www.rmuti.ac.th/user/kedkarn/impfile/RGB_to_HSI.pdf
pub fn toHsi(rgb: anytype) Hsi(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(rgb.r, F);
    const g = rgbCast(rgb.g, F);
    const b = rgbCast(rgb.b, F);

    const xmax = @max(r, g, b);
    const xmin = @min(r, g, b);
    const chroma = xmax - xmin;

    // Intensity
    const i = (r + g + b) / 3.0;

    // Saturation
    var s: F = 0.0;
    if (i != 0) {
        s = 1.0 - (xmin / i);
    }

    // Hue
    var h: ?F = null;
    if (chroma != 0) {
        h = computeHue(F, r, g, b, xmax, xmin);
    }

    return Hsi(F).init(h, s, i);
}

// Formula for sRGB -> HSL conversion:
// https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
pub fn toHsl(rgb: anytype) Hsl(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(rgb.r, F);
    const g = rgbCast(rgb.g, F);
    const b = rgbCast(rgb.b, F);

    const xmax = @max(r, g, b);
    const xmin = @min(r, g, b);
    const chroma = xmax - xmin;

    // Lightness
    const l = (xmax + xmin) / 2.0;

    // Hue
    var h: ?F = null;
    if (chroma != 0) {
        h = computeHue(F, r, g, b, xmax, xmin);
    }

    // Saturation
    var s: F = 0.0;
    if (l != 0 and l != 1) {
        s = chroma / (1.0 - @abs(2.0 * l - 1.0));
    }

    return Hsl(F).init(h, s, l);
}

// Formula for sRGB -> HSL conversion:
// https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
pub fn toHsv(rgb: anytype) Hsv(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(rgb.r, F);
    const g = rgbCast(rgb.g, F);
    const b = rgbCast(rgb.b, F);

    // Value
    const xmax = @max(r, g, b);
    const xmin = @min(r, g, b);
    const chroma = xmax - xmin;

    // Hue
    var h: ?F = null;
    if (chroma != 0) {
        h = computeHue(F, r, g, b, xmax, xmin);
    }

    // Saturation
    var s: F = 0.0;
    if (xmax != 0) {
        s = chroma / xmax;
    }

    return Hsv(F).init(h, s, xmax);
}

// Formula for sRGB -> HWB conversion:
// https://www.w3.org/TR/css-color-4/#rgb-to-hwb
pub fn toHwb(rgb: anytype) Hwb(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(rgb.r, F);
    const g = rgbCast(rgb.g, F);
    const b = rgbCast(rgb.b, F);

    const xmax = @max(r, g, b);
    const xmin = @min(r, g, b);

    // Whiteness
    const white = xmin;

    // Blackness
    const black = 1.0 - xmax;

    // Hue
    const epsilon: F = 1 / 100000; // for floating point error
    var h: ?F = null;
    if (white + black < 1 - epsilon) {
        h = computeHue(F, r, g, b, xmax, xmin);
    }

    return Hwb(F).init(h, white, black);
}

/// Typically, the hue of HSI, HSL, HSV, and HWB is calulcated via an trigonemetric algorithm as
/// such:
///
/// ```zig
/// const numerator = 0.5 * ((self.r - self.g) + (self.r - self.b));
/// const denominator = std.math.sqrt((self.r - self.g) * (self.r - self.g) + (self.r - self.b) * (self.g - self.b));
/// var h = std.math.acos(numerator / denominator) * 180 / std.math.pi;
/// if (self.b > self.g) {
///     h = 360.0 - h;
/// }
/// ```
///
/// or in plaintext:
///
/// ```
/// N = 0.5[(R - G) + (R - B)] = R - ((G + B) / 2)
/// D = sqrt(pow(R - G, 2) + (R - B) * (G - B))
/// Hue = acos(N / D)
/// ```
///
/// To avoid expensive functions like acos() and sqrt(), we can use the max RGB channel and min
/// RGB channel to calculate the hue instead. When we consider that each 60° sector will have a
/// most dominant channel and least dominant channel, the above cosine ratio can be simplified
/// to a linear function, where `C = max(R, G, B) - min(R, G, B)` represents the chroma and the
/// subscript to `Hue` represents the most dominant channel.
///
/// ```
/// Hue_R = 60 * (((G - B) / C) % 6)
/// Hue_G = 60 * ((B - R) / C) + 2)
/// Hue_B = 60 * ((R - B) / C) + 4)
/// ```
///
/// Note:
/// * Each one of ((R, G, B) - (R, G, B) / C) will be in the range [-1, 1]
/// * `Hue_R` represents the 300°-60° sector, so it has no offset, but must be guaranteed to be
/// within positive bounds, thus the modulo is used to ensure this (alternatively you could
/// conditionally check for negativity and add 360°)
/// * `Hue_G` represents the 60°-180° sector, so it is offset by 2 (120°)
/// * `Hue_B` represents the 180°-300° sector, so it is offset by 4 (240°)
fn computeHue(comptime F: type, r: F, g: F, b: F, xmax: F, xmin: F) F {
    const chroma = xmax - xmin;
    var h: F = 0;
    if (xmax == r) {
        h = 60.0 * @mod((g - b) / chroma, 6);
    } else if (xmax == g) {
        h = 60.0 * ((b - r) / chroma + 2.0);
    } else if (xmax == b) {
        h = 60.0 * ((r - g) / chroma + 4.0);
    } else {
        unreachable;
    }

    return h;
}

// Casting an RGB type (u8 or float)
// val: a u8 or float value
// U: the destination type (u8 or float)
pub fn rgbCast(val: anytype, comptime U: type) U {
    const T = @TypeOf(val);
    validation.assertRgbType(U);

    if (T == U) {
        return val;
    }

    // At this point, T and U have already been verified to be valid backing types. The only valid
    // integer type T or U could be is u8, so we can implicitly cast to it.
    return switch (@typeInfo(T)) {
        .float => switch (@typeInfo(U)) {
            .int => @as(u8, @intFromFloat(@round(val * 255))),
            .float => @as(U, @floatCast(val)),
            else => unreachable,
        },
        .int => switch (@typeInfo(U)) {
            .int => val,
            .float => @as(U, @floatFromInt(val)),
            else => unreachable,
        },
        else => unreachable,
    };
}

// ============================================================================
// TESTS
// ============================================================================

// ==========================
// HexRgb
// ==========================
test "HexRgb formatting" {
    const alloc = std.testing.allocator;

    const hex = HexRgb.initFromU8(200, 100, 50);
    const exp_format: []const u8 = "(c86432)";
    const exp_default: []const u8 = "(c86432)";
    const exp_raw: []const u8 = "HexRgb.{ .value = 13132850 }";
    const exp_pretty: []const u8 = "HexRgb(#C86432)";
    const act_format: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{hex});
    const act_default: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{hex.formatter(.default)});
    const act_raw: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{hex.formatter(.raw)});
    const act_pretty: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{hex.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);
}

test "HexRgb initFromString" {
    var hex = try HexRgb.initFromString("C86432");
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    const hex_str1 = "000000";
    hex = try HexRgb.initFromString(hex_str1);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = try HexRgb.initFromString("#ffffff");
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    const hex_str2 = "#16C82D";
    hex = try HexRgb.initFromString(hex_str2);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);

    // Should error when given a string not in "#RRGGBB" or "RRGGBB" format
    const actual_err = HexRgb.initFromString("0x123456");
    const expected_err = RgbError.InvalidHexString;
    try std.testing.expectError(expected_err, actual_err);
}

test "HexRgb initFromU8" {
    var hex = HexRgb.initFromU8(200, 100, 50);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU8(0, 0, 0);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU8(255, 255, 255);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU8(22, 200, 45);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexRgb initFromU24" {
    var hex = HexRgb.initFromU24(0xc86432);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU24(0x000000);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU24(0xffffff);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexRgb.initFromU24(0x16c82d);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexRgb initFromSrgb(u8)" {
    var srgb_val = Srgb(u8).init(200, 100, 50);
    var hex = HexRgb.initFromSrgb(srgb_val);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(u8).init(0, 0, 0);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(u8).init(255, 255, 255);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(u8).init(22, 200, 45);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexRgb initFromSrgb(f32)" {
    var srgb_val = Srgb(f32).init(0.784, 0.392, 0.196);
    var hex = HexRgb.initFromSrgb(srgb_val);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f32).init(0, 0, 0);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f32).init(1, 1, 1);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f32).init(0.086, 0.784, 0.176);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexRgb initFromSrgb(f64)" {
    var srgb_val = Srgb(f64).init(0.784, 0.392, 0.196);
    var hex = HexRgb.initFromSrgb(srgb_val);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f64).init(0, 0, 0);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f64).init(1, 1, 1);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb_val = Srgb(f64).init(0.086, 0.784, 0.176);
    hex = HexRgb.initFromSrgb(srgb_val);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexRgb toSrgb(u8)" {
    var hex = HexRgb.initFromU24(0xc86432);
    var srgb_val = hex.toSrgb(u8);
    var expected = Srgb(u8).init(200, 100, 50);
    try std.testing.expectEqual(expected, srgb_val);

    hex = HexRgb.initFromU24(0x000000);
    srgb_val = hex.toSrgb(u8);
    expected = Srgb(u8).init(0, 0, 0);
    try std.testing.expectEqual(expected, srgb_val);

    hex = HexRgb.initFromU24(0xffffff);
    srgb_val = hex.toSrgb(u8);
    expected = Srgb(u8).init(255, 255, 255);
    try std.testing.expectEqual(expected, srgb_val);

    hex = HexRgb.initFromU24(0x16c82d);
    srgb_val = hex.toSrgb(u8);
    expected = Srgb(u8).init(22, 200, 45);
    try std.testing.expectEqual(expected, srgb_val);
}

test "HexRgb toSrgb(f32)" {
    const tolerance = 0.002;

    var hex = HexRgb.initFromU24(0xc86432);
    var srgb_val = hex.toSrgb(f32);
    var expected = Srgb(f32).init(0.784, 0.392, 0.196);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0x000000);
    srgb_val = hex.toSrgb(f32);
    expected = Srgb(f32).init(0, 0, 0);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0xffffff);
    srgb_val = hex.toSrgb(f32);
    expected = Srgb(f32).init(1, 1, 1);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0x16c82d);
    srgb_val = hex.toSrgb(f32);
    expected = Srgb(f32).init(0.086, 0.784, 0.176);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);
}

test "HexRgb toSrgb(f64)" {
    const tolerance = 0.000002;

    var hex = HexRgb.initFromU24(0xc86432);
    var srgb_val = hex.toSrgb(f64);
    var expected = Srgb(f64).init(0.784314, 0.392157, 0.196078);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0x000000);
    srgb_val = hex.toSrgb(f64);
    expected = Srgb(f64).init(0, 0, 0);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0xffffff);
    srgb_val = hex.toSrgb(f64);
    expected = Srgb(f64).init(1, 1, 1);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);

    hex = HexRgb.initFromU24(0x16c82d);
    srgb_val = hex.toSrgb(f64);
    expected = Srgb(f64).init(0.086275, 0.784314, 0.176471);
    try validation.expectColorsApproxEqAbs(expected, srgb_val, tolerance);
}
