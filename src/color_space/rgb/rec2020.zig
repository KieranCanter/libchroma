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
const REC2020_TO_XYZ: [3][3]f32 = .{
    .{ 0.6369580483012914, 0.14461690358620832, 0.1688809751641721 },
    .{ 0.2627002120112671, 0.6779980715188708, 0.05930171646986196 },
    .{ 0.000000000000000, 0.028072693049087428, 1.060985057710791 },
};
const XYZ_TO_REC2020: [3][3]f32 = .{
    .{ 1.716651187971268, -0.355670783776392, -0.253366281373660 },
    .{ -0.666684351832489, 1.616481236634939, 0.0157685458139111 },
    .{ 0.017639857445311, -0.042770613257809, 0.942103121235474 },
};

/// Type to hold a non-linear Rec. 2020 value. This is a display-referred variant that uses the EOTF
/// specified in the Rec. 1886 spec (2.4 gamma). Rec. 2020 covers about 75.8% of the CIE 1931
/// chromaticity gamut.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Rec2020(comptime T: type) type {
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
            try writer.print("Rec2020({s})({f})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return self.toLinear().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return LinearRec2020(T).fromXyz(xyz).toRec2020();
        }

        pub fn toLinear(self: Self) LinearRec2020(T) {
            return LinearRec2020(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Rec. 2020 EOTF is the same as Rec. 1886, located in Annex 1:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.1886-0-201103-I!!PDF-E.pdf
        fn gammaToLinear(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            fl = sign * std.math.pow(F, abs, 1.0 / 2.4);

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

/// Type to hold a non-linear Rec. 2020 value. This is a scene-referred variant that uses the OETF
/// specified in the Rec. 2020 spec.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Rec2020Scene(comptime T: type) type {
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
            try writer.print("Rec2020Scene({s})({f})", .{ @typeName(T), self });
        }

        pub inline fn cast(self: Self, comptime U: type) Rec2020Scene(U) {
            const r = rgbCast(U, self.r);
            const g = rgbCast(U, self.g);
            const b = rgbCast(U, self.b);
            return Rec2020Scene(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return self.toLinear().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return LinearRec2020(T).fromXyz(xyz).toRec2020Scene();
        }

        pub fn toLinear(self: Self) LinearRec2020(T) {
            return LinearRec2020(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Rec. 2020 OETF is defined in Table 4:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2020-2-201510-I!!PDF-E.pdf
        fn gammaToLinear(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            const alpha: F = 1.09929682680944;
            const beta: F = 0.018053968510807;

            if (abs < beta) {
                fl *= 4.5;
            } else {
                fl = sign * (alpha * std.math.pow(F, abs, 0.45) - (alpha - 1));
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

/// Type to hold a linearized Rec. 2020 value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearRec2020(comptime T: type) type {
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
            try writer.print("LinearRec2020({s})({f})", .{ @typeName(T), self });
        }

        pub fn toXyz(self: Self) Xyz(F) {
            return rgb.linearToXyz(REC2020_TO_XYZ, self);
        }

        pub fn fromXyz(xyz: anytype) Self {
            return rgb.linearFromXyz(Self, XYZ_TO_REC2020, xyz);
        }

        pub fn toRec2020(self: Self) Rec2020(T) {
            return Rec2020(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }

        pub fn toRec2020Scene(self: Self) Rec2020Scene(T) {
            return Rec2020Scene(T).init(
                linearToGammaOetf(self.r),
                linearToGammaOetf(self.g),
                linearToGammaOetf(self.b),
            );
        }

        // Rec. 2020 EOTF is the same as Rec. 1886, located in Annex 1:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.1886-0-201103-I!!PDF-E.pdf
        fn linearToGamma(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            fl = sign * std.math.pow(F, abs, 2.4);

            return rgb.fromFloat(T, fl);
        }

        // Rec. 2020 OETF is defined in Table 4:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2020-2-201510-I!!PDF-E.pdf
        fn linearToGammaOetf(val: T) T {
            var fl = rgb.toFloat(F, val);
            const sign: F = if (fl < 0) -1 else 1;
            const abs: F = fl * sign;

            const alpha: F = 1.09929682680944;
            const beta: F = 0.018053968510807;

            if (abs <= beta * 4.5) {
                fl /= 4.5;
            } else {
                fl = sign * std.math.pow(F, (abs + alpha - 1) / alpha, 1.0 / 0.45);
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

test "Rec2020(f32) <-> XYZ round-trip" {
    const original = Rec2020(f32).init(0.8, 0.4, 0.2);
    const result = Rec2020(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Rec2020(f64) <-> XYZ round-trip" {
    const original = Rec2020(f64).init(0.8, 0.4, 0.2);
    const result = Rec2020(f64).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol64);
}

test "Rec2020(f32) toXyz known values" {
    const xyz = Rec2020(f32).init(0.8, 0.4, 0.2).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.765, 0.733, 0.562), xyz, tol32);

    // White -> D65
    const white = Rec2020(f32).init(1, 1, 1).toXyz();
    try chroma_testing.expectColorsApproxEqAbs(Xyz(f32).init(0.950, 1.000, 1.089), white, tol32);

    try std.testing.expectEqual(Xyz(f32).init(0, 0, 0), Rec2020(f32).init(0, 0, 0).toXyz());
}

test "Rec2020(f32) <-> LinearRec2020 round-trip" {
    const original = Rec2020(f32).init(0.8, 0.4, 0.2);
    const result = original.toLinear().toRec2020();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Rec2020Scene(f32) <-> XYZ round-trip" {
    const original = Rec2020Scene(f32).init(0.8, 0.4, 0.2);
    const result = Rec2020Scene(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Rec2020Scene(f32) <-> LinearRec2020 round-trip" {
    const original = Rec2020Scene(f32).init(0.8, 0.4, 0.2);
    const result = original.toLinear().toRec2020Scene();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol32);
}

test "Rec2020 <-> sRGB cross-space" {
    // sRGB(0.8, 0.4, 0.2) -> XYZ -> Rec2020
    const srgb_xyz = Srgb(f32).init(0.8, 0.4, 0.2).toXyz();
    const r20 = Rec2020(f32).fromXyz(srgb_xyz);
    try chroma_testing.expectColorsApproxEqAbs(Rec2020(f32).init(0.128, 0.013, 0.001), r20, tol32);
}
