const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const color_formatter = @import("../../color_formatter.zig");
const white_point = @import("../white_point.zig");

const CieLch = @import("../lch/cie_lch.zig").CieLch;
const CieXyz = @import("../xyz/cie_xyz.zig").CieXyz;

/// Type to hold a CIE L*a*b* value under the D65 illuminant (2° observer).
///
/// l: lightness in [0, 100]
/// a: green–red axis, roughly [-128, 127]
/// b: blue–yellow axis, roughly [-128, 127]
pub fn CieLab(comptime T: type) type {
    assertFloatType(T);

    const wp = white_point.d65;
    const epsilon: T = 216.0 / 24389.0; // ~ 0.008856 <- actual CIE standard
    const kappa: T = 24389.0 / 27.0; // ~ 903.3 <- actual CIE standard

    return struct {
        const Self = @This();
        pub const Backing = T;

        l: T,
        a: T,
        b: T,

        pub fn init(l: T, a: T, b: T) Self {
            return .{ .l = l, .a = a, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d}, {d}, {d}", .{ self.l, self.a, self.b });
        }

        // CIE Lab -> XYZ (D65)
        // http://www.brucelindbloom.com/index.html?Eqn_Lab_to_XYZ.html
        pub fn toCieXyz(self: Self) CieXyz(T) {
            const fy = (self.l + 16.0) / 116.0;
            const fx = (self.a / 500.0) + fy;
            const fz = fy - (self.b / 200.0);

            const xr = if (fx * fx * fx > epsilon)
                fx * fx * fx
            else
                (116.0 * fx - 16.0) / kappa;

            const yr = if (self.l > kappa * epsilon)
                fy * fy * fy
            else
                self.l / kappa;

            const zr = if (fz * fz * fz > epsilon)
                fz * fz * fz
            else
                (116.0 * fz - 16.0) / kappa;

            const wp_x: T = @floatCast(wp.x);
            const wp_y: T = @floatCast(wp.y);
            const wp_z: T = @floatCast(wp.z);

            return CieXyz(T).init(
                xr * wp_x,
                yr * wp_y,
                zr * wp_z,
            );
        }

        // XYZ (D65) -> CIE Lab
        // http://www.brucelindbloom.com/index.html?Eqn_XYZ_to_Lab.html
        pub fn fromCieXyz(xyz: CieXyz(T)) Self {
            const wp_x: T = @floatCast(wp.x);
            const wp_y: T = @floatCast(wp.y);
            const wp_z: T = @floatCast(wp.z);

            const xr = xyz.x / wp_x;
            const yr = xyz.y / wp_y;
            const zr = xyz.z / wp_z;

            const fx = if (xr > epsilon)
                std.math.cbrt(xr)
            else
                (kappa * xr + 16.0) / 116.0;

            const fy = if (yr > epsilon)
                std.math.cbrt(yr)
            else
                (kappa * yr + 16.0) / 116.0;

            const fz = if (zr > epsilon)
                std.math.cbrt(zr)
            else
                (kappa * zr + 16.0) / 116.0;

            return Self.init(
                116.0 * fy - 16.0,
                500.0 * (fx - fy),
                200.0 * (fy - fz),
            );
        }

        // Lab -> LCH (cartesian to polar)
        // https://en.wikipedia.org/wiki/CIELAB_color_space#Cylindrical_model
        pub fn toLch(self: Self) CieLch(T) {
            const threshold: T = if (T == f64) 1e-12 else 1e-6;
            const c = @sqrt(self.a * self.a + self.b * self.b);
            if (c < threshold) { // consider this color achromatic if chroma is under certain threshold
                return CieLch(T).init(self.l, 0, null);
            }

            var h = std.math.atan2(self.b, self.a) * (180.0 / std.math.pi); // h = atan(b/a)
            if (h < 0) h += 360.0;
            return CieLch(T).init(self.l, c, h);
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");

test "CieLab(f32) fromCieXyz" {
    const tolerance = 0.002;

    // D65 white -> Lab(100, 0, 0)
    var xyz = CieXyz(f32).init(0.95047, 1.0, 1.08883);
    var expected = CieLab(f32).init(100.0, 0.0, 0.0);
    var actual = CieLab(f32).fromCieXyz(xyz);
    try chroma_testing.expectColorsApproxEqAbs(expected, actual, tolerance);

    // Black
    xyz = CieXyz(f32).init(0, 0, 0);
    expected = CieLab(f32).init(0, 0, 0);
    actual = CieLab(f32).fromCieXyz(xyz);
    try std.testing.expectEqual(expected, actual);

    // sRGB(200, 100, 50) -> XYZ(0.2895, 0.2163, 0.0567) -> Lab
    xyz = CieXyz(f32).init(0.2895, 0.2163, 0.0567);
    expected = CieLab(f32).init(53.632, 36.275, 45.370);
    actual = CieLab(f32).fromCieXyz(xyz);
    try chroma_testing.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "CieLab(f64) fromCieXyz" {
    const tolerance = 0.000002;

    var xyz = CieXyz(f64).init(0.95047, 1.0, 1.08883);
    var expected = CieLab(f64).init(100.0, 0.0, 0.0);
    var actual = CieLab(f64).fromCieXyz(xyz);
    try chroma_testing.expectColorsApproxEqAbs(expected, actual, tolerance);

    xyz = CieXyz(f64).init(0, 0, 0);
    expected = CieLab(f64).init(0, 0, 0);
    actual = CieLab(f64).fromCieXyz(xyz);
    try std.testing.expectEqual(expected, actual);
}

test "CieLab(f32) toCieXyz round-trip" {
    const tolerance = 0.002;

    const original = CieXyz(f32).init(0.2895, 0.2163, 0.0567);
    const lab = CieLab(f32).fromCieXyz(original);
    const result = lab.toCieXyz();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tolerance);
}

test "CieLab(f64) toCieXyz round-trip" {
    const tolerance = 0.000002;

    const original = CieXyz(f64).init(0.289514, 0.216258, 0.056673);
    const lab = CieLab(f64).fromCieXyz(original);
    const result = lab.toCieXyz();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tolerance);
}

test "CieLab(f32) toLch" {
    const tolerance = 0.002;

    // Achromatic (a=0, b=0) -> chroma=0, hue=null
    var lab = CieLab(f32).init(50.0, 0.0, 0.0);
    var lch = lab.toLch();
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), lch.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lch.c, tolerance);
    try std.testing.expectEqual(@as(?f32, null), lch.h);

    // Chromatic
    lab = CieLab(f32).init(53.539, 30.344, 40.602);
    lch = lab.toLch();
    try std.testing.expectApproxEqAbs(@as(f32, 53.539), lch.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 50.688), lch.c, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 53.227), lch.h.?, tolerance);
}
