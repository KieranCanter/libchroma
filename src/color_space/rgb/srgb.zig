const std = @import("std");
const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");
const color_formatter = @import("../../color_formatter.zig");
const rgb = @import("../rgb.zig");

const Cmyk = @import("../cmyk.zig").Cmyk;
const Hsi = @import("../hsi.zig").Hsi;
const Hsl = @import("../hsl.zig").Hsl;
const Hsv = @import("../hsv.zig").Hsv;
const Hwb = @import("../hwb.zig").Hwb;
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

        /// Initialize from a 24-bit hex value (0xRRGGBB).
        pub fn initFromHex(hex: u24) Self {
            const r: u8 = @intCast(hex >> 16 & 0xFF);
            const g: u8 = @intCast(hex >> 8 & 0xFF);
            const b: u8 = @intCast(hex & 0xFF);
            if (T == u8) return Self.init(r, g, b);
            return Self.init(
                @as(T, @floatFromInt(r)) / 255.0,
                @as(T, @floatFromInt(g)) / 255.0,
                @as(T, @floatFromInt(b)) / 255.0,
            );
        }

        /// Initialize from a hex string in "RRGGBB" or "#RRGGBB" format.
        pub fn initFromHexString(hex_str: []const u8) rgb.RgbError!Self {
            return initFromHex(try rgb.parseHexString(hex_str));
        }

        /// Pack into a 24-bit hex value (0xRRGGBB).
        pub fn toHex(self: Self) u24 {
            if (T == u8) return rgb.packHex(self.r, self.g, self.b);
            const r: u8 = @intFromFloat(@round(self.r * 255.0));
            const g: u8 = @intFromFloat(@round(self.g * 255.0));
            const b: u8 = @intFromFloat(@round(self.b * 255.0));
            return rgb.packHex(r, g, b);
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d:.4}, {d:.4}, {d:.4}", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Srgb({s})({f})[#{X}]", .{ @typeName(T), self, self.toHex() });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return self.toLinear().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            const srgb_f = LinearSrgb(F).fromXyz(xyz).toSrgb();
            if (T == F) return srgb_f;
            // T is u8, F is f32 — convert float sRGB to u8
            return Self.init(
                rgb.fromFloat(T, srgb_f.r),
                rgb.fromFloat(T, srgb_f.g),
                rgb.fromFloat(T, srgb_f.b),
            );
        }

        pub fn toLinear(self: Self) LinearSrgb(F) {
            return LinearSrgb(F).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Formulae for sRGB <-> Linear conversions:
        // https://entropymine.com/imageworsener/srgbformula/
        fn gammaToLinear(val: T) F {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            if (abs <= 0.04045) {
                fl /= 12.92;
            } else {
                fl = sign * std.math.pow(F, (abs + 0.055) / 1.055, 2.4);
            }

            return fl;
        }

        pub fn toCmyk(self: Self) Cmyk(F) {
            return rgb.toCmyk(self);
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

        pub fn isInGamut(self: Self) bool {
            return rgb.isInGamut(self);
        }

        pub fn clamp(self: Self) Self {
            return rgb.clampRgb(Self, self);
        }
    };
}

/// Type to hold a linearized sRGB value.
///
/// r: red value in [0.0, 1.0]
/// g: green value in [0.0, 1.0]
/// b: blue value in [0.0, 1.0]
pub fn LinearSrgb(comptime T: type) type {
    validation.assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

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
            try writer.print("{d:.4}, {d:.4}, {d:.4}", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("LinearSrgb({s})({f})", .{ @typeName(T), self });
        }

        pub fn toXyz(self: Self) Xyz(T) {
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

        fn linearToGamma(val: T) T {
            var fl = val;
            const sign: T = if (fl < 0) -1 else 1;
            const abs: T = fl * sign;

            if (fl <= 0.0031308) {
                fl *= 12.92;
            } else {
                fl = sign * (1.055 * std.math.pow(T, abs, 1.0 / 2.4) - 0.055);
            }

            return fl;
        }

        pub fn isInGamut(self: Self) bool {
            return rgb.isInGamut(self);
        }

        pub fn clamp(self: Self) Self {
            return rgb.clampRgb(Self, self);
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const tol32 = 0.002;
const tol64 = 0.000002;

// --- Srgb gamma <-> linear ---

test "Srgb(f32) <-> LinearSrgb round-trip" {
    const original = Srgb(f32).init(0.8, 0.4, 0.2);
    const result = original.toLinear().toSrgb();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Srgb(f64) <-> LinearSrgb round-trip" {
    const original = Srgb(f64).init(0.8, 0.4, 0.2);
    const result = original.toLinear().toSrgb();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol64);
}

test "Srgb gamma edge cases" {
    // Black
    const black = Srgb(f32).init(0, 0, 0).toLinear();
    try std.testing.expectEqual(LinearSrgb(f32).init(0, 0, 0), black);

    // White
    const white = Srgb(f32).init(1, 1, 1).toLinear();
    try chroma_testing.expectColorsApproxEqAbs(LinearSrgb(f32).init(1, 1, 1), white, tol32);

    // Below linear threshold (0.04045)
    const low = Srgb(f32).init(0.03, 0.03, 0.03).toLinear();
    try chroma_testing.expectColorsApproxEqAbs(LinearSrgb(f32).init(0.00232, 0.00232, 0.00232), low, tol32);
}

// --- Srgb <-> XYZ ---

test "Srgb(f32) <-> XYZ round-trip" {
    const original = Srgb(f32).init(0.8, 0.4, 0.2);
    const result = Srgb(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Srgb(f64) <-> XYZ round-trip" {
    const original = Srgb(f64).init(0.8, 0.4, 0.2);
    const result = Srgb(f64).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol64);
}

test "Srgb(f32) toXyz known values" {
    // sRGB(0.8, 0.4, 0.2) -> XYZ
    const xyz = Srgb(f32).init(0.8, 0.4, 0.2).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.302, 0.226, 0.059), xyz, tol32);

    // White -> D65 white point
    const white = Srgb(f32).init(1, 1, 1).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.950, 1.000, 1.089), white, tol32);

    // Black
    try std.testing.expectEqual(Xyz(f32).init(0, 0, 0), Srgb(f32).init(0, 0, 0).toXyz());
}

// --- Srgb → cylindrical/subtractive shortcuts ---

test "Srgb(f32) toHsl" {
    // Chromatic
    const hsl = Srgb(f32).init(0.8, 0.4, 0.2).toHsl();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsl.h.?, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.600), hsl.s, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.500), hsl.l, tol32);

    // Achromatic -> null hue
    try std.testing.expectEqual(@as(?f32, null), Srgb(f32).init(0.5, 0.5, 0.5).toHsl().h);
}

test "Srgb(f32) toHsv" {
    const hsv = Srgb(f32).init(0.8, 0.4, 0.2).toHsv();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsv.h.?, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.750), hsv.s, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), hsv.v, tol32);

    try std.testing.expectEqual(@as(?f32, null), Srgb(f32).init(0, 0, 0).toHsv().h);
}

test "Srgb(f32) toHwb" {
    const hwb = Srgb(f32).init(0.8, 0.4, 0.2).toHwb();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hwb.h.?, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), hwb.w, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), hwb.b, tol32);

    // White + black >= 1 -> null hue
    try std.testing.expectEqual(@as(?f32, null), Srgb(f32).init(1, 1, 1).toHwb().h);
}

test "Srgb(f32) toHsi" {
    const hsi = Srgb(f32).init(0.8, 0.4, 0.2).toHsi();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsi.h.?, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.571), hsi.s, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.467), hsi.i, tol32);

    try std.testing.expectEqual(@as(?f32, null), Srgb(f32).init(0, 0, 0).toHsi().h);
}

test "Srgb(f32) toCmyk" {
    const cmyk = Srgb(f32).init(0.8, 0.4, 0.2).toCmyk();
    try std.testing.expectApproxEqAbs(@as(f32, 0.000), cmyk.c, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.500), cmyk.m, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.750), cmyk.y, tol32);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), cmyk.k, tol32);

    // Black -> K=1
    const black = Srgb(f32).init(0, 0, 0).toCmyk();
    try std.testing.expectEqual(@as(f32, 1.0), black.k);

    // White -> all zero
    try std.testing.expectEqual(Cmyk(f32).init(0, 0, 0, 0), Srgb(f32).init(1, 1, 1).toCmyk());
}

// --- Srgb u8 implicit cast ---

test "Srgb(u8) toXyz produces f32" {
    const xyz = Srgb(u8).init(200, 100, 50).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.289, 0.216, 0.056), xyz, tol32);
}

// --- LinearSrgb ---

test "LinearSrgb(f32) <-> XYZ round-trip" {
    const original = LinearSrgb(f32).init(0.604, 0.133, 0.033);
    const result = LinearSrgb(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "LinearSrgb(f32) toXyz known values" {
    const xyz = LinearSrgb(f32).init(0.604, 0.133, 0.033).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.302, 0.226, 0.059), xyz, tol32);
}
