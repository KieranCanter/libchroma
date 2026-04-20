const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const color_formatter = @import("../../color_formatter.zig");

const CieLab = @import("../lab/cie_lab.zig").CieLab;
const CieXyz = @import("../xyz/cie_xyz.zig").CieXyz;

/// CIE LCH(ab) color, cylindrical form of CIE L*a*b*.
/// `l`: lightness in [0, 100]
/// `c`: chroma in [0, ~181]
/// `h`: hue in [0, 360) or `null` when achromatic
pub fn CieLch(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        l: T,
        c: T,
        h: ?T,

        pub fn init(l: T, c: T, h: ?T) Self {
            return .{ .l = l, .c = c, .h = h };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d}, {d}, {?d}", .{ self.l, self.c, self.h });
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self.toLab().toCieXyz();
        }

        pub fn fromCieXyz(xyz: CieXyz(T)) Self {
            return CieLab(T).fromCieXyz(xyz).toLch();
        }

        // LCH -> Lab (polar to cartesian)
        pub fn toLab(self: Self) CieLab(T) {
            if (self.h == null) {
                return CieLab(T).init(self.l, 0, 0);
            }

            const h_rad = self.h.? * (std.math.pi / 180.0);
            return CieLab(T).init(
                self.l,
                self.c * @cos(h_rad),
                self.c * @sin(h_rad),
            );
        }
    };
}

// Tests

const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");

test "CieLch(f32) toLab achromatic" {
    const tolerance = 0.002;

    const lch = CieLch(f32).init(50.0, 0.0, null);
    const lab = lch.toLab();
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), lab.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lab.a, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lab.b, tolerance);
}

test "CieLch(f32) toLab chromatic" {
    const tolerance = 0.002;

    const lch = CieLch(f32).init(53.539, 50.688, 53.227);
    const lab = lch.toLab();
    try std.testing.expectApproxEqAbs(@as(f32, 53.539), lab.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 30.344), lab.a, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 40.602), lab.b, tolerance);
}

test "CieLch(f32) Lab round-trip" {
    const tolerance = 0.002;

    const original = CieLab(f32).init(53.539, 30.344, 40.602);
    const lch = original.toLch();
    const result = lch.toLab();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tolerance);
}

test "CieLch(f64) Lab round-trip" {
    const tolerance = 0.000002;

    const original = CieLab(f64).init(53.539, 30.344, 40.602);
    const lch = original.toLch();
    const result = lch.toLab();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tolerance);
}

test "CieLch(f32) XYZ round-trip" {
    const tolerance = 0.002;

    const original = CieXyz(f32).init(0.2895, 0.2163, 0.0567);
    const lch = CieLch(f32).fromCieXyz(original);
    const result = lch.toCieXyz();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tolerance);
}
