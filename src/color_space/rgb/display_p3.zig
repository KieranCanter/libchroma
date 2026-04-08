const std = @import("std");
const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");
const color_formatter = @import("../../color_formatter.zig");
const rgb = @import("../rgb.zig");
const rgbCast = @import("../rgb.zig").rgbCast;

const Cmyk = @import("../cmyk.zig").Cmyk;
const Hsi = @import("../hsi.zig").Hsi;
const Hsl = @import("../hsl.zig").Hsl;
const Hsv = @import("../hsv.zig").Hsv;
const Hwb = @import("../hwb.zig").Hwb;
const Xyz = @import("../xyz.zig").Xyz;
const Yxy = @import("../yxy.zig").Yxy;

// Method for computing 3x3 RGB <-> XYZ matrices:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const P3_TO_XYZ: [3][3]f32 = .{
    .{ 0.4865709486482162, 0.26566769316909306, 0.1982172852343625 },
    .{ 0.2289745640697488, 0.6917385218365064, 0.079286914093745 },
    .{ 0.0000000000000000, 0.04511338185890264, 1.043944368900976 },
};
const XYZ_TO_P3: [3][3]f32 = .{
    .{ 2.493496911941425, -0.9313836179191239, -0.40271078445071684 },
    .{ -0.8294889695615747, 1.7626640603183463, 0.023624685841943577 },
    .{ 0.03584583024378447, -0.07617238926804182, 0.9568845240076872 },
};

/// Type to hold a non-linear Display-P3 value. A variant of DCI-P3 (which was originally developed
/// by Digital Cinema Intiatives, LLC for theatrical digital motion picture distribution),
/// Display-P3 was developed by Apple for wide-gamut displays. It covers about 53.6% of the CIE 1931
/// chromaticity gamut.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn DisplayP3(comptime T: type) type {
    validation.assertFloatType(T);

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
            try writer.print("{d:.4}, {d:.4}, {d:.4}", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("DisplayP3({s})({f})", .{ @typeName(T), self });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return self.toLinear().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return LinearDisplayP3(T).fromXyz(xyz).toP3();
        }

        pub fn toLinear(self: Self) LinearDisplayP3(T) {
            return LinearDisplayP3(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Same gamma conversion formula as sRGB:
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

/// Type to hold a linearized Display-P3 value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearDisplayP3(comptime T: type) type {
    validation.assertFloatType(T);

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
            try writer.print("{d:.4}, {d:.4}, {d:.4}", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("LinearDisplayP3({s})({f})", .{ @typeName(T), self });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return rgb.linearToXyz(P3_TO_XYZ, self);
        }

        pub fn fromXyz(xyz: anytype) Self {
            return rgb.linearFromXyz(Self, XYZ_TO_P3, xyz);
        }

        pub fn toP3(self: Self) DisplayP3(T) {
            return DisplayP3(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }

        // Same gamma conversion formula as sRGB:
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

const Srgb = @import("srgb.zig").Srgb;

const tol32 = 0.002;
const tol64 = 0.000002;

test "DisplayP3(f32) <-> XYZ round-trip" {
    const original = DisplayP3(f32).init(0.8, 0.4, 0.2);
    const result = DisplayP3(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "DisplayP3(f64) <-> XYZ round-trip" {
    const original = DisplayP3(f64).init(0.8, 0.4, 0.2);
    const result = DisplayP3(f64).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol64);
}

test "DisplayP3(f32) toXyz known values" {
    const xyz = DisplayP3(f32).init(0.8, 0.4, 0.2).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.336, 0.233, 0.041), xyz, tol32);

    // White -> D65
    const white = DisplayP3(f32).init(1, 1, 1).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.950, 1.000, 1.089), white, tol32);

    try std.testing.expectEqual(Xyz(f32).init(0, 0, 0), DisplayP3(f32).init(0, 0, 0).toXyz());
}

test "DisplayP3(f32) <-> LinearDisplayP3 round-trip" {
    const original = DisplayP3(f32).init(0.8, 0.4, 0.2);
    const result = original.toLinear().toP3();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "DisplayP3 <-> sRGB cross-space" {
    // sRGB(0.8, 0.4, 0.2) -> XYZ -> P3
    const srgb_xyz = Srgb(f32).init(0.8, 0.4, 0.2).toXyz();
    const p3 = DisplayP3(f32).fromXyz(srgb_xyz);
    try chroma_testing.expectColorsApproxEqAbs(DisplayP3(f32).init(0.749, 0.422, 0.248), p3, tol32);
}
