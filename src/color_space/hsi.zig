const std = @import("std");
const assertFloatType = @import("../validation.zig").assertFloatType;
const validation = @import("../validation.zig");
const chroma_testing = @import("../testing.zig");
const color_formatter = @import("../color_formatter.zig");

const Hsl = @import("hsl.zig").Hsl;
const Hsv = @import("hsv.zig").Hsv;
const Srgb = @import("rgb/srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold an HSI value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// i: intensity value in [0.0, 1.0]
pub fn Hsi(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        h: ?T,
        s: T,
        i: T,

        pub fn init(h: ?T, s: T, i: T) Self {
            return .{ .h = h, .s = s, .i = i };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{?d:.4}, {d:.4}, {d:.4}", .{ self.h, self.s, self.i });
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toHsi();
        }

        // Formula for HSI -> sRGB conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSI_to_RGB
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                return Srgb(T).init(self.i, self.i, self.i);
            }

            const h = self.h.?;
            const hprime = h / 60.0;
            const sector: u8 = @intFromFloat(@floor(hprime));
            const z = 1.0 - @abs(@mod(hprime, 2.0) - 1.0);
            const chroma = (3.0 * self.i * self.s) / (1.0 + z);
            const x = chroma * z;
            const m = self.i * (1.0 - self.s);

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
    };
}

// ============================================================================
// TESTS
// ============================================================================

const tol = 0.002;

test "Hsi(f32) toSrgb" {
    // HSI(20, 0.571, 0.467) ~ sRGB(0.8, 0.4, 0.2)
    const c = Hsi(f32).init(20.0, 0.571, 0.467).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), c.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.400), c.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), c.b, tol);

    // Achromatic
    const gray = Hsi(f32).init(null, 0, 0.5).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), gray.r, tol);
}

test "Hsi(f32) <-> XYZ round-trip" {
    const original = Hsi(f32).init(20.0, 0.571, 0.467);
    const result = Hsi(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}
