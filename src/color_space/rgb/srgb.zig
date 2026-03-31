const std = @import("std");
const validation = @import("../../validation.zig");
const color_formatter = @import("../../color_formatter.zig");
const rgb = @import("../rgb.zig");

const Cmyk = @import("../cmyk.zig").Cmyk;
const Hsi = @import("../hsi.zig").Hsi;
const Hsl = @import("../hsl.zig").Hsl;
const Hsv = @import("../hsv.zig").Hsv;
const Hwb = @import("../hwb.zig").Hwb;
const HexRgb = rgb.HexRgb;
const Xyz = @import("../xyz.zig").Xyz;

const rgbCast = rgb.rgbCast;
const RgbError = rgb.RgbError;

// Method for computing 3x3 RGB <-> XYZ matrices:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const SRGB_TO_XYZ: [3][3]f32 = .{
    .{ 0.41239079926595934, 0.357584339383878, 0.1804807884018343 },
    .{ 0.21263900587151027, 0.715168678767756, 0.07219231536073371 },
    .{ 0.01933081871559182, 0.11919477979462598, 0.9505321522496607 },
};
const XYZ_TO_SRGB: [3][3]f32 = .{
    .{ 3.2409699419045226, -1.537383177570094, -0.4986107602930034 },
    .{ -0.9692436362808796, 1.8759675015077202, 0.04155505740717559 },
    .{ 0.05563007969699366, -0.20397695888897652, 1.0569715142428786 },
};

/// Type to hold a non-linear sRGB value. If you're looking for just normal "RGB," this is probably
/// the type you're looking for. While a common standard for digital displays, sRGB only covers
/// about 35.9% of the CIE 1931 chromaticity gamut, while newer RGB color space specifications like
/// Display-P3 and Rec. 2020 offer wider gamut ranges.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Srgb(comptime T: type) type {
    validation.assertRgbType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;
        const F = validation.rgbToFloatType(T);

        r: T,
        g: T,
        b: T,

        pub fn init(r: T, g: T, b: T) Self {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            const hex = self.toHex();
            try writer.print("Srgb({s})({d}, {d}, {d}) #{X}", .{ @typeName(T), self.r, self.g, self.b, hex.value });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return self.toLinear().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return LinearSrgb(T).fromXyz(xyz).toSrgb();
        }

        pub fn toLinear(self: Self) LinearSrgb(T) {
            return LinearSrgb(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Formulae for sRGB <-> Linear conversions:
        // https://entropymine.com/imageworsener/srgbformula/
        fn gammaToLinear(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            if (abs <= 0.04045) {
                fl /= 12.92;
            } else {
                fl = sign * std.math.pow(F, (abs + 0.055) / 1.055, 2.4);
            }

            return rgb.fromFloat(T, fl);
        }

        pub fn toCmyk(self: Self) Cmyk(F) {
            return rgb.toCmyk(self);
        }

        pub fn toHex(self: Self) HexRgb {
            return HexRgb.initFromSrgb(self);
        }

        pub fn toHsi(self: Self) Hsi(F) {
            return rgb.toHsi(self);
        }

        pub fn toHsl(self: Self) Hsl(F) {
            return rgb.toHsl(self);
        }

        pub fn toHsv(self: Self) Hsv(F) {
            return rgb.toHsv(self);
        }

        pub fn toHwb(self: Self) Hwb(F) {
            return rgb.toHwb(self);
        }
    };
}

/// Type to hold a linearized sRGB value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearSrgb(comptime T: type) type {
    validation.assertRgbType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;
        const F = validation.rgbToFloatType(T);

        r: T,
        g: T,
        b: T,

        pub fn init(r: T, g: T, b: T) Self {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("LinearSrgb({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return rgb.linearToXyz(SRGB_TO_XYZ, self);
        }

        pub fn fromXyz(xyz: anytype) Self {
            return rgb.linearFromXyz(Self, XYZ_TO_SRGB, xyz);
        }

        pub fn toSrgb(self: Self) Srgb(T) {
            return Srgb(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }

        // Formulae for sRGB <-> Linear conversions:
        // https://entropymine.com/imageworsener/srgbformula/
        fn linearToGamma(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            if (fl <= 0.0031308) {
                fl *= 12.92;
            } else {
                fl = sign * (1.055 * std.math.pow(F, abs, 1.0 / 2.4) - 0.055);
            }

            return rgb.fromFloat(T, fl);
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

// ===========================
// Srgb
// ===========================
test "Srgb formatting" {
    const alloc = std.testing.allocator;

    const srgb_u8 = Srgb(u8).init(200, 100, 50);
    var exp_format: []const u8 = "(200, 100, 50)";
    var exp_default: []const u8 = "(200, 100, 50)";
    var exp_raw: []const u8 = "Srgb(u8).{ .r = 200, .g = 100, .b = 50 }";
    var exp_pretty: []const u8 = "Srgb(u8)(200, 100, 50) #C86432";
    var act_format: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{srgb_u8});
    var act_default: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{srgb_u8.formatter(.default)});
    var act_raw: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{srgb_u8.formatter(.raw)});
    var act_pretty: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{srgb_u8.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);

    const srgb_f32 = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    exp_format = "(0.784, 0.392, 0.196)";
    exp_default = "(0.784, 0.392, 0.196)";
    exp_raw = "Srgb(f32).{ .r = 0.784, .g = 0.392, .b = 0.196 }";
    exp_pretty = "Srgb(f32)(0.784, 0.392, 0.196) #C86432";
    act_format = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f32});
    act_default = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f32.formatter(.default)});
    act_raw = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f32.formatter(.raw)});
    act_pretty = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f32.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);

    const srgb_f64 = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    exp_format = "(0.784313, 0.392156, 0.196078)";
    exp_default = "(0.784313, 0.392156, 0.196078)";
    exp_raw = "Srgb(f64).{ .r = 0.784313, .g = 0.392156, .b = 0.196078 }";
    exp_pretty = "Srgb(f64)(0.784313, 0.392156, 0.196078) #C86432";
    act_format = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f64});
    act_default = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f64.formatter(.default)});
    act_raw = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f64.formatter(.raw)});
    act_pretty = try std.fmt.allocPrint(alloc, "{f}", .{srgb_f64.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);
}

test "Srgb(u8) toLinear" {
    const tolerance: u8 = 1;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = LinearSrgb(u8).init(147, 32, 8);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = LinearSrgb(u8).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = LinearSrgb(u8).init(255, 255, 255);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = LinearSrgb(u8).init(2, 147, 7);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toLinear" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = LinearSrgb(f32).init(0.578, 0.127, 0.032);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = LinearSrgb(f32).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = LinearSrgb(f32).init(1, 1, 1);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = LinearSrgb(f32).init(0.008, 0.577, 0.026);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toLinear" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = LinearSrgb(f64).init(0.577580, 0.127438, 0.031896);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = LinearSrgb(f64).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = LinearSrgb(f64).init(1, 1, 1);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = LinearSrgb(f64).init(0.008023, 0.577580, 0.026241);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toXyz" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Xyz(f32).init(0.289, 0.216, 0.056);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Xyz(f32).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Xyz(f32).init(0.950, 1.000, 1.089);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Xyz(f32).init(0.214, 0.417, 0.093);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toXyz" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Xyz(f32).init(0.289, 0.216, 0.056);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Xyz(f32).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Xyz(f32).init(0.950, 1.000, 1.089);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Xyz(f32).init(0.214, 0.417, 0.093);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toXyz" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Xyz(f64).init(0.289514, 0.216258, 0.056673);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Xyz(f64).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Xyz(f64).init(0.950456, 1.000000, 1.089058);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Xyz(f64).init(0.214578, 0.416667, 0.093942);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) fromXyz" {
    const tol32 = 0.002;
    const tol64 = 0.000002;

    var xyz32 = Xyz(f32).init(0.289, 0.216, 0.056);
    var xyz64 = Xyz(f64).init(0.289514, 0.216258, 0.056673);
    var expected32 = Srgb(f32).init(0.784, 0.392, 0.194); // (200, 100, 50)
    var expected64 = Srgb(f32).init(0.784312, 0.392158, 0.196078); // (200, 100, 50)
    var actual32 = Srgb(f32).fromXyz(xyz32);
    var actual64 = Srgb(f32).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected32, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);

    xyz32 = Xyz(f32).init(0, 0, 0);
    xyz64 = Xyz(f64).init(0, 0, 0);
    expected32 = Srgb(f32).init(0, 0, 0);
    expected64 = Srgb(f32).init(0, 0, 0);
    actual32 = Srgb(f32).fromXyz(xyz32);
    actual64 = Srgb(f32).fromXyz(xyz64);
    try std.testing.expectEqual(expected32, actual32);
    try std.testing.expectEqual(expected64, actual64);

    xyz32 = Xyz(f32).init(0.950, 1.000, 1.089);
    xyz64 = Xyz(f64).init(0.950456, 1.000000, 1.089058);
    expected32 = Srgb(f32).init(1, 1, 1);
    expected64 = Srgb(f32).init(1, 1, 1);
    actual32 = Srgb(f32).fromXyz(xyz32);
    actual64 = Srgb(f32).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected64, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);

    xyz32 = Xyz(f32).init(0.214, 0.417, 0.093);
    xyz64 = Xyz(f64).init(0.214578, 0.416667, 0.093942);
    expected32 = Srgb(f32).init(0.071, 0.785, 0.172); // (22, 200, 45)
    expected64 = Srgb(f32).init(0.086278, 0.784313, 0.176468); // (22, 200, 45)
    actual32 = Srgb(f32).fromXyz(xyz32);
    actual64 = Srgb(f32).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected32, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);
}

test "Srgb(f64) fromXyz" {
    const tol32 = 0.002;
    const tol64 = 0.000002;

    var xyz32 = Xyz(f32).init(0.289, 0.216, 0.056);
    var xyz64 = Xyz(f64).init(0.289514, 0.216258, 0.056673);
    var expected32 = Srgb(f64).init(0.784, 0.392, 0.194); // (200, 100, 50)
    var expected64 = Srgb(f64).init(0.784312, 0.392158, 0.196078); // (200, 100, 50)
    var actual32 = Srgb(f64).fromXyz(xyz32);
    var actual64 = Srgb(f64).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected32, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);

    xyz32 = Xyz(f32).init(0, 0, 0);
    xyz64 = Xyz(f64).init(0, 0, 0);
    expected32 = Srgb(f64).init(0, 0, 0);
    expected64 = Srgb(f64).init(0, 0, 0);
    actual32 = Srgb(f64).fromXyz(xyz32);
    actual64 = Srgb(f64).fromXyz(xyz64);
    try std.testing.expectEqual(expected32, actual32);
    try std.testing.expectEqual(expected64, actual64);

    xyz32 = Xyz(f32).init(0.950, 1.000, 1.089);
    xyz64 = Xyz(f64).init(0.950456, 1.000000, 1.089058);
    expected32 = Srgb(f64).init(1, 1, 1);
    expected64 = Srgb(f64).init(1, 1, 1);
    actual32 = Srgb(f64).fromXyz(xyz32);
    actual64 = Srgb(f64).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected32, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);

    xyz32 = Xyz(f32).init(0.214, 0.417, 0.093);
    xyz64 = Xyz(f64).init(0.214578, 0.416667, 0.093942);
    expected32 = Srgb(f64).init(0.071, 0.785, 0.172); // (22, 200, 45)
    expected64 = Srgb(f64).init(0.086278, 0.784313, 0.176468); // (22, 200, 45)
    actual32 = Srgb(f64).fromXyz(xyz32);
    actual64 = Srgb(f64).fromXyz(xyz64);
    try validation.expectColorsApproxEqAbs(expected32, actual32, tol32);
    try validation.expectColorsApproxEqAbs(expected64, actual64, tol64);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toCmyk" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Cmyk(f32).init(0.000, 0.500, 0.750, 0.216);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Cmyk(f32).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Cmyk(f32).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Cmyk(f32).init(0.890, 0.000, 0.775, 0.216);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toCmyk" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Cmyk(f32).init(0.000, 0.500, 0.750, 0.216);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Cmyk(f32).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Cmyk(f32).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Cmyk(f32).init(0.890, 0.000, 0.775, 0.216);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toCmyk" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Cmyk(f64).init(0.000000, 0.500001, 0.750000, 0.215687);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Cmyk(f64).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Cmyk(f64).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Cmyk(f64).init(0.890001, 0.000000, 0.775001, 0.215687);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsi" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsi(f32).init(19.999, 0.571, 0.458);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsi(f32).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsi(f32).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsi(f32).init(127.753, 0.753, 0.349);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsi" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsi(f32).init(19.999, 0.571, 0.458);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsi(f32).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsi(f32).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsi(f32).init(127.736, 0.753, 0.349);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsi" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsi(f64).init(19.999966, 0.571429, 0.457516);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsi(f64).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsi(f64).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsi(f64).init(127.752805, 0.752810, 0.349019);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsl" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsl(f32).init(19.999, 0.600, 0.490);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsl(f32).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsl(f32).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsl(f32).init(127.753, 0.802, 0.435);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsl" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsl(f32).init(19.999, 0.600, 0.490);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsl(f32).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsl(f32).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsl(f32).init(127.736, 0.802, 0.435);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsl" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsl(f64).init(19.999966, 0.600000, 0.490196);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsl(f64).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsl(f64).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsl(f64).init(127.752805, 0.801803, 0.435294);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsv" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsv(f32).init(19.999, 0.750, 0.784);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsv(f32).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsv(f32).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsv(f32).init(127.753, 0.890, 0.784);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsv" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsv(f32).init(19.999, 0.750, 0.784);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsv(f32).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsv(f32).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsv(f32).init(127.736, 0.890, 0.784);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsv" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsv(f64).init(19.999966, 0.750000, 0.784313);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsv(f64).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsv(f64).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsv(f64).init(127.752805, 0.890001, 0.784313);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHwb" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hwb(f32).init(19.999, 0.196, 0.216);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hwb(f32).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hwb(f32).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hwb(f32).init(127.753, 0.086, 0.216);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHwb" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hwb(f32).init(19.999, 0.196, 0.216);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hwb(f32).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hwb(f32).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hwb(f32).init(127.736, 0.086, 0.216);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHwb" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hwb(f64).init(19.999966, 0.196078, 0.215687);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hwb(f64).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hwb(f64).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hwb(f64).init(127.752805, 0.086274, 0.215687);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// ===========================
// LinearSrgb
// ===========================
test "LinearSrgb formatting" {
    const alloc = std.testing.allocator;

    const linear_u8 = LinearSrgb(u8).init(200, 100, 50);
    var exp_format: []const u8 = "(200, 100, 50)";
    var exp_default: []const u8 = "(200, 100, 50)";
    var exp_raw: []const u8 = "LinearSrgb(u8).{ .r = 200, .g = 100, .b = 50 }";
    var exp_pretty: []const u8 = "LinearSrgb(u8)(200, 100, 50)";
    var act_format: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{linear_u8});
    var act_default: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{linear_u8.formatter(.default)});
    var act_raw: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{linear_u8.formatter(.raw)});
    var act_pretty: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{linear_u8.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);

    const linear_f32 = LinearSrgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    exp_format = "(0.784, 0.392, 0.196)";
    exp_default = "(0.784, 0.392, 0.196)";
    exp_raw = "LinearSrgb(f32).{ .r = 0.784, .g = 0.392, .b = 0.196 }";
    exp_pretty = "LinearSrgb(f32)(0.784, 0.392, 0.196)";
    act_format = try std.fmt.allocPrint(alloc, "{f}", .{linear_f32});
    act_default = try std.fmt.allocPrint(alloc, "{f}", .{linear_f32.formatter(.default)});
    act_raw = try std.fmt.allocPrint(alloc, "{f}", .{linear_f32.formatter(.raw)});
    act_pretty = try std.fmt.allocPrint(alloc, "{f}", .{linear_f32.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);

    const linear_f64 = LinearSrgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    exp_format = "(0.784313, 0.392156, 0.196078)";
    exp_default = "(0.784313, 0.392156, 0.196078)";
    exp_raw = "LinearSrgb(f64).{ .r = 0.784313, .g = 0.392156, .b = 0.196078 }";
    exp_pretty = "LinearSrgb(f64)(0.784313, 0.392156, 0.196078)";
    act_format = try std.fmt.allocPrint(alloc, "{f}", .{linear_f64});
    act_default = try std.fmt.allocPrint(alloc, "{f}", .{linear_f64.formatter(.default)});
    act_raw = try std.fmt.allocPrint(alloc, "{f}", .{linear_f64.formatter(.raw)});
    act_pretty = try std.fmt.allocPrint(alloc, "{f}", .{linear_f64.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);
}

test "LinearSrgb(u8) toSrgb" {
    const tolerance: u8 = 1;

    var linear = LinearSrgb(u8).init(147, 32, 8);
    var expected = Srgb(u8).init(200, 100, 49);
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(u8).init(0, 0, 0);
    expected = Srgb(u8).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(u8).init(255, 255, 255);
    expected = Srgb(u8).init(255, 255, 255);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(u8).init(2, 147, 7);
    expected = Srgb(u8).init(22, 200, 45);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "LinearSrgb(f32) toSrgb" {
    const tolerance = 0.002;

    var linear = LinearSrgb(f32).init(0.578, 0.127, 0.032);
    var expected = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f32).init(0, 0, 0);
    expected = Srgb(f32).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(f32).init(1, 1, 1);
    expected = Srgb(f32).init(1, 1, 1);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f32).init(0.008, 0.577, 0.026);
    expected = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "LinearSrgb(f64) toSrgb" {
    const tolerance = 0.000002;

    var linear = LinearSrgb(f64).init(0.577580, 0.127438, 0.031896);
    var expected = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f64).init(0, 0, 0);
    expected = Srgb(f64).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(f64).init(1, 1, 1);
    expected = Srgb(f64).init(1, 1, 1);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f64).init(0.008023, 0.577580, 0.026241);
    expected = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}
