const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const fmt = @import("../../fmt.zig");

const Oklab = @import("../lab/oklab.zig").Oklab;
const CieXyz = @import("../xyz/cie_xyz.zig").CieXyz;

/// OKLCH color, cylindrical form of OKLab.
/// `l`: perceived lightness in [0, 1]
/// `c`: chroma in [0, ~0.4]
/// `h`: hue in [0, 360) or `null` when achromatic
pub fn Oklch(comptime T: type) type {
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

        pub fn formatter(self: Self, style: fmt.FormatStyle) fmt.TypeFormat(Self) {
            return fmt.TypeFormat(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d}, {d}, {?d}", .{ self.l, self.c, self.h });
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self.toOklab().toCieXyz();
        }

        pub fn fromCieXyz(xyz: CieXyz(T)) Self {
            return Oklab(T).fromCieXyz(xyz).toOklch();
        }

        // OKLCH -> OKLab (polar to cartesian)
        pub fn toOklab(self: Self) Oklab(T) {
            if (self.h == null) {
                return Oklab(T).init(self.l, 0, 0);
            }
            const h_rad = self.h.? * (std.math.pi / 180.0);
            return Oklab(T).init(
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

const tol: f32 = 0.002;
const tol64: f64 = 0.000002;

test "Oklch(f32) toOklab achromatic" {
    const oklch = Oklch(f32).init(0.5, 0.0, null);
    const oklab = oklch.toOklab();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), oklab.l, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), oklab.a, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), oklab.b, tol);
}

test "Oklch(f32) toOklab chromatic" {
    const oklch = Oklch(f32).init(0.628, 0.258, 29.234);
    const oklab = oklch.toOklab();
    try std.testing.expectApproxEqAbs(@as(f32, 0.628), oklab.l, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.225), oklab.a, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.126), oklab.b, tol);
}

test "Oklch(f32) Oklab round-trip" {
    const original = Oklab(f32).init(0.628, 0.225, 0.126);
    const oklch = original.toOklch();
    const result = oklch.toOklab();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "Oklch(f64) Oklab round-trip" {
    const original = Oklab(f64).init(0.628, 0.225, 0.126);
    const oklch = original.toOklch();
    const result = oklch.toOklab();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol64);
}

test "Oklch(f32) XYZ round-trip" {
    const original = CieXyz(f32).init(0.2895, 0.2163, 0.0567);
    const oklch = Oklch(f32).fromCieXyz(original);
    const result = oklch.toCieXyz();
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}
