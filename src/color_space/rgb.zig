const std = @import("std");
const validation = @import("../validation.zig");
const color_formatter = @import("../color_formatter.zig");
const rgbToFloatType = validation.rgbToFloatType;

pub const srgb = @import("rgb/srgb.zig");
pub const display_p3 = @import("rgb/display_p3.zig");
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

// Hex parsing utilities (used by Srgb.initFromHex / initFromHexString)

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

pub fn parseHexString(hex_str: []const u8) RgbError!u24 {
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

pub fn packHex(r: u8, g: u8, b: u8) u24 {
    return @as(u24, r) << 16 | @as(u16, g) << 8 | b;
}

pub fn linearToXyz(matrix: [3][3]f32, linear: anytype) Xyz(rgbToFloatType(@TypeOf(linear).Backing)) {
    const F = rgbToFloatType(@TypeOf(linear).Backing);
    const lin_r = rgbCast(F, linear.r);
    const lin_g = rgbCast(F, linear.g);
    const lin_b = rgbCast(F, linear.b);

    return Xyz(F).init(
        lin_r * @as(F, matrix[0][0]) + lin_g * @as(F, matrix[0][1]) + lin_b * @as(F, matrix[0][2]),
        lin_r * @as(F, matrix[1][0]) + lin_g * @as(F, matrix[1][1]) + lin_b * @as(F, matrix[1][2]),
        lin_r * @as(F, matrix[2][0]) + lin_g * @as(F, matrix[2][1]) + lin_b * @as(F, matrix[2][2]),
    );
}

pub fn linearFromXyz(comptime LinearRgb: type, matrix: [3][3]f32, xyz: anytype) LinearRgb {
    const F = rgbToFloatType(@TypeOf(xyz).Backing);
    const T = LinearRgb.Backing;

    const lin_r = xyz.x * @as(F, matrix[0][0]) + xyz.y * @as(F, matrix[0][1]) + xyz.z * @as(F, matrix[0][2]);
    const lin_g = xyz.x * @as(F, matrix[1][0]) + xyz.y * @as(F, matrix[1][1]) + xyz.z * @as(F, matrix[1][2]);
    const lin_b = xyz.x * @as(F, matrix[2][0]) + xyz.y * @as(F, matrix[2][1]) + xyz.z * @as(F, matrix[2][2]);

    return LinearRgb.init(
        rgbCast(T, lin_r),
        rgbCast(T, lin_g),
        rgbCast(T, lin_b),
    );
}

// Formula for sRGB -> CMYK conversion:
// https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
pub fn toCmyk(rgb: anytype) Cmyk(rgbToFloatType(@TypeOf(rgb).Backing)) {
    const F = rgbToFloatType(@TypeOf(rgb).Backing);

    const r = rgbCast(F, rgb.r);
    const g = rgbCast(F, rgb.g);
    const b = rgbCast(F, rgb.b);

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

    const r = rgbCast(F, rgb.r);
    const g = rgbCast(F, rgb.g);
    const b = rgbCast(F, rgb.b);

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

    const r = rgbCast(F, rgb.r);
    const g = rgbCast(F, rgb.g);
    const b = rgbCast(F, rgb.b);

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

    const r = rgbCast(F, rgb.r);
    const g = rgbCast(F, rgb.g);
    const b = rgbCast(F, rgb.b);

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

    const g = toFloat(F, rgb.g);
    const r = toFloat(F, rgb.r);
    const b = toFloat(F, rgb.b);

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

// Convert val of backing type to a float value
// F: destination float type
// val: a u8 or float value
pub fn toFloat(comptime F: type, val: anytype) F {
    comptime {
        if (@typeInfo(F) != .float)
            @compileError("toFloat() requires a float destination type");
    }

    return switch (@typeInfo(@TypeOf(val))) {
        .int => @as(F, @floatFromInt(val)) / 255.0,
        .float => @floatCast(val),
        else => unreachable,
    };
}

// Convert to backing type T from a float val
// T: destination type (u8 or float)
// val: float value
pub fn fromFloat(comptime T: type, val: anytype) T {
    comptime {
        if (@typeInfo(@TypeOf(val)) != .float)
            @compileError("fromFloat() requires a float `val` input");
    }

    return switch (@typeInfo(T)) {
        .int => @as(u8, @intFromFloat(@round(val * 255.0))),
        .float => @floatCast(val),
        else => unreachable,
    };
}

// Casting an RGB type (u8 or float)
// U: the destination type (u8 or float)
// val: a u8 or float value
pub fn rgbCast(comptime U: type, val: anytype) U {
    const T = @TypeOf(val);
    validation.assertRgbType(U);

    if (T == U) {
        return val;
    }

    // At this point, T and U have already been verified to be valid backing types. If the
    // destination type U is an integer (u8), we can assume the source type T of `val` is a float.
    // If T was u8, it would have returned in the conditional above, so we can safely call fromFloat
    // on `val`.
    return switch (@typeInfo(U)) {
        .float => toFloat(U, val),
        .int => fromFloat(U, val),
        else => unreachable,
    };
}

pub fn isInGamut(rgb_color: anytype) bool {
    const T = @TypeOf(rgb_color);
    const F = rgbToFloatType(T.Backing);
    const r = toFloat(F, rgb_color.r);
    const g = toFloat(F, rgb_color.g);
    const b = toFloat(F, rgb_color.b);
    return r >= 0 and r <= 1 and g >= 0 and g <= 1 and b >= 0 and b <= 1;
}

pub fn clampRgb(comptime RgbType: type, rgb_color: anytype) RgbType {
    const T = RgbType.Backing;
    return switch (@typeInfo(T)) {
        .int => rgb_color, // u8 is always in [0, 255]
        .float => RgbType.init(
            @max(@as(T, 0), @min(@as(T, 1), rgb_color.r)),
            @max(@as(T, 0), @min(@as(T, 1), rgb_color.g)),
            @max(@as(T, 0), @min(@as(T, 1), rgb_color.b)),
        ),
        else => unreachable,
    };
}

// ============================================================================
// TESTS
// ============================================================================

// ==========================
// Srgb hex methods
// ==========================

test "Srgb initFromHexString" {
    var c = try Srgb(u8).initFromHexString("C86432");
    try std.testing.expectEqual(Srgb(u8).init(200, 100, 50), c);

    c = try Srgb(u8).initFromHexString("#ffffff");
    try std.testing.expectEqual(Srgb(u8).init(255, 255, 255), c);

    c = try Srgb(u8).initFromHexString("000000");
    try std.testing.expectEqual(Srgb(u8).init(0, 0, 0), c);

    c = try Srgb(u8).initFromHexString("#16C82D");
    try std.testing.expectEqual(Srgb(u8).init(22, 200, 45), c);

    const actual_err = Srgb(u8).initFromHexString("0x123456");
    try std.testing.expectError(RgbError.InvalidHexString, actual_err);
}

test "Srgb(u8) initFromHex" {
    var c = Srgb(u8).initFromHex(0xc86432);
    try std.testing.expectEqual(Srgb(u8).init(200, 100, 50), c);

    c = Srgb(u8).initFromHex(0x000000);
    try std.testing.expectEqual(Srgb(u8).init(0, 0, 0), c);

    c = Srgb(u8).initFromHex(0xffffff);
    try std.testing.expectEqual(Srgb(u8).init(255, 255, 255), c);

    c = Srgb(u8).initFromHex(0x16c82d);
    try std.testing.expectEqual(Srgb(u8).init(22, 200, 45), c);
}

test "Srgb(f32) initFromHex" {
    const tolerance = 0.002;

    var c = Srgb(f32).initFromHex(0xc86432);
    try validation.expectColorsApproxEqAbs(Srgb(f32).init(0.784, 0.392, 0.196), c, tolerance);

    c = Srgb(f32).initFromHex(0x000000);
    try std.testing.expectEqual(Srgb(f32).init(0, 0, 0), c);

    c = Srgb(f32).initFromHex(0xffffff);
    try std.testing.expectEqual(Srgb(f32).init(1, 1, 1), c);

    c = Srgb(f32).initFromHex(0x16c82d);
    try validation.expectColorsApproxEqAbs(Srgb(f32).init(0.086, 0.784, 0.176), c, tolerance);
}

test "Srgb(f64) initFromHex" {
    const tolerance = 0.000002;

    var c = Srgb(f64).initFromHex(0xc86432);
    try validation.expectColorsApproxEqAbs(Srgb(f64).init(0.784314, 0.392157, 0.196078), c, tolerance);

    c = Srgb(f64).initFromHex(0x000000);
    try std.testing.expectEqual(Srgb(f64).init(0, 0, 0), c);

    c = Srgb(f64).initFromHex(0xffffff);
    try std.testing.expectEqual(Srgb(f64).init(1, 1, 1), c);

    c = Srgb(f64).initFromHex(0x16c82d);
    try validation.expectColorsApproxEqAbs(Srgb(f64).init(0.086275, 0.784314, 0.176471), c, tolerance);
}

test "Srgb(u8) toHex" {
    try std.testing.expectEqual(@as(u24, 0xc86432), Srgb(u8).init(200, 100, 50).toHex());
    try std.testing.expectEqual(@as(u24, 0x000000), Srgb(u8).init(0, 0, 0).toHex());
    try std.testing.expectEqual(@as(u24, 0xffffff), Srgb(u8).init(255, 255, 255).toHex());
    try std.testing.expectEqual(@as(u24, 0x16c82d), Srgb(u8).init(22, 200, 45).toHex());
}

test "Srgb(f32) toHex" {
    try std.testing.expectEqual(@as(u24, 0xc86432), Srgb(f32).init(0.784, 0.392, 0.196).toHex());
    try std.testing.expectEqual(@as(u24, 0x000000), Srgb(f32).init(0, 0, 0).toHex());
    try std.testing.expectEqual(@as(u24, 0xffffff), Srgb(f32).init(1, 1, 1).toHex());
    try std.testing.expectEqual(@as(u24, 0x16c82d), Srgb(f32).init(0.086, 0.784, 0.176).toHex());
}

test "Srgb(f64) toHex" {
    try std.testing.expectEqual(@as(u24, 0xc86432), Srgb(f64).init(0.784, 0.392, 0.196).toHex());
    try std.testing.expectEqual(@as(u24, 0x000000), Srgb(f64).init(0, 0, 0).toHex());
    try std.testing.expectEqual(@as(u24, 0xffffff), Srgb(f64).init(1, 1, 1).toHex());
    try std.testing.expectEqual(@as(u24, 0x16c82d), Srgb(f64).init(0.086, 0.784, 0.176).toHex());
}

test "Srgb hex round-trip" {
    // u8 -> hex -> u8
    const original_u8 = Srgb(u8).init(200, 100, 50);
    try std.testing.expectEqual(original_u8, Srgb(u8).initFromHex(original_u8.toHex()));

    // f32 -> hex -> f32 (lossy due to u8 quantization)
    const tolerance = 0.002;
    const original_f32 = Srgb(f32).init(0.784, 0.392, 0.196);
    const round_tripped = Srgb(f32).initFromHex(original_f32.toHex());
    try validation.expectColorsApproxEqAbs(original_f32, round_tripped, tolerance);
}
