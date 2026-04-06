const std = @import("std");
const assertFloatType = @import("../validation.zig").assertFloatType;
const color_formatter = @import("../color_formatter.zig");

const Lab = @import("lab.zig").Lab;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold a CIE LCH(ab) value (the cylindrical form of CIE L*a*b*).
///
/// l: lightness in [0, 100]
/// c: chroma in [0, ~181]
/// h: hue angle in [0, 360) or null when chroma is 0 (achromatic)
pub fn Lch(comptime T: type) type {
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
            try writer.print("{d}, {d}, {?}", .{ self.l, self.c, self.h });
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toLab().toXyz();
        }

        pub fn fromXyz(xyz: Xyz(T)) Self {
            return Lab(T).fromXyz(xyz).toLch();
        }

        // LCH -> Lab (polar to cartesian)
        pub fn toLab(self: Self) Lab(T) {
            if (self.h == null) {
                return Lab(T).init(self.l, 0, 0);
            }

            const h_rad = self.h.? * (std.math.pi / 180.0);
            return Lab(T).init(
                self.l,
                self.c * @cos(h_rad),
                self.c * @sin(h_rad),
            );
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const validation = @import("../validation.zig");

test "Lch(f32) toLab achromatic" {
    const tolerance = 0.002;

    const lch = Lch(f32).init(50.0, 0.0, null);
    const lab = lch.toLab();
    try std.testing.expectApproxEqAbs(@as(f32, 50.0), lab.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lab.a, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), lab.b, tolerance);
}

test "Lch(f32) toLab chromatic" {
    const tolerance = 0.002;

    const lch = Lch(f32).init(53.539, 50.688, 53.227);
    const lab = lch.toLab();
    try std.testing.expectApproxEqAbs(@as(f32, 53.539), lab.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 30.344), lab.a, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 40.602), lab.b, tolerance);
}

test "Lch(f32) Lab round-trip" {
    const tolerance = 0.002;

    const original = Lab(f32).init(53.539, 30.344, 40.602);
    const lch = original.toLch();
    const result = lch.toLab();
    try validation.expectColorsApproxEqAbs(original, result, tolerance);
}

test "Lch(f64) Lab round-trip" {
    const tolerance = 0.000002;

    const original = Lab(f64).init(53.539, 30.344, 40.602);
    const lch = original.toLch();
    const result = lch.toLab();
    try validation.expectColorsApproxEqAbs(original, result, tolerance);
}

test "Lch(f32) XYZ round-trip" {
    const tolerance = 0.002;

    const original = Xyz(f32).init(0.2895, 0.2163, 0.0567);
    const lch = Lch(f32).fromXyz(original);
    const result = lch.toXyz();
    try validation.expectColorsApproxEqAbs(original, result, tolerance);
}
