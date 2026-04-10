const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");
const color_formatter = @import("../../color_formatter.zig");

const Hsv = @import("hsv.zig").Hsv;
const Srgb = @import("../rgb/srgb.zig").Srgb;
const CieXyz = @import("../xyz/cie_xyz.zig").CieXyz;

/// Type to hold an HSL value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// l: lightness value in [0.0, 1.0]
pub fn Hsl(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        h: ?T,
        s: T,
        l: T,

        pub fn init(h: ?T, s: T, l: T) Self {
            return .{ .h = h, .s = s, .l = l };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{?d}, {d}, {d}", .{ self.h, self.s, self.l });
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self.toSrgb().toCieXyz();
        }

        pub fn fromCieXyz(xyz: anytype) Self {
            return Srgb(T).fromCieXyz(xyz).toHsl();
        }

        // Formula for HSL -> sRGB conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                return Srgb(T).init(self.l, self.l, self.l);
            }

            const h = self.h.?;
            const chroma = (1.0 - @abs(2 * self.l - 1.0)) * self.s;
            const hprime = h / 60.0;
            const sector: u8 = @intFromFloat(@floor(hprime));
            const x = chroma * (1.0 - @abs(@mod(hprime, 2.0) - 1.0));
            const m = self.l - (chroma / 2.0);

            return switch (sector) {
                0, 6 => Srgb(T).init(chroma + m, x + m, m),
                1 => Srgb(T).init(x + m, chroma + m, m),
                2 => Srgb(T).init(m, chroma + m, x + m),
                3 => Srgb(T).init(m, x + m, chroma + m),
                4 => Srgb(T).init(x + m, m, chroma + m),
                5 => Srgb(T).init(chroma + m, m, x + m),
                else => unreachable,
            };
        }

        // Formula for HSL -> HSV conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_HSV
        pub fn toHsv(self: Self) Hsv(T) {
            // Value
            const v = self.l + self.s * @min(self.l, 1 - self.l);

            // Saturation
            var s: f32 = 0.0;
            if (v != 0.0) {
                s = 2.0 * (1.0 - (self.l / v));
            }

            // Hue remains same

            return Hsv(T).init(
                self.h,
                s,
                v,
            );
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const tol = 0.002;

test "Hsl(f32) toSrgb" {
    const c = Hsl(f32).init(20.0, 0.6, 0.5).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), c.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.400), c.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), c.b, tol);

    // Achromatic (null hue) -> gray
    const gray = Hsl(f32).init(null, 0, 0.5).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), gray.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), gray.g, tol);
}

test "Hsl(f32) <-> XYZ round-trip" {
    const original = Hsl(f32).init(20.0, 0.6, 0.5);
    const result = Hsl(f32).fromCieXyz(original.toCieXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "Hsl(f32) toHsv" {
    const hsv = Hsl(f32).init(20.0, 0.6, 0.5).toHsv();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsv.h.?, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.750), hsv.s, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), hsv.v, tol);
}
