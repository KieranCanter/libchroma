const std = @import("std");
const assertFloatType = @import("../validation.zig").assertFloatType;
const validation = @import("../validation.zig");
const chroma_testing = @import("../testing.zig");
const color_formatter = @import("../color_formatter.zig");

const Hsl = @import("hsl.zig").Hsl;
const Hwb = @import("hwb.zig").Hwb;
const Srgb = @import("rgb/srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold an HSV value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// v: value value in [0.0, 1.0]
pub fn Hsv(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        h: ?T,
        s: T,
        v: T,

        pub fn init(h: ?T, s: T, v: T) Self {
            return .{ .h = h, .s = s, .v = v };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{?d:.4}, {d:.4}, {d:.4}", .{ self.h, self.s, self.v });
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toHsv();
        }

        // Formula for HSV -> sRGB conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                return Srgb(T).init(self.v, self.v, self.v);
            }

            const h = self.h.?;
            const chroma = self.v * self.s;
            const hprime = h / 60.0;
            const sector: u8 = @intFromFloat(@floor(hprime));
            const x = chroma * (1.0 - @abs(@mod(hprime, 2.0) - 1.0));
            const m = self.v - chroma;

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

        // Formula for HSV -> HSL conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_HSL
        pub fn toHsl(self: Self) Hsl(T) {
            // Lightness
            const l = self.v * (1.0 - (self.s / 2.0));

            // Saturation
            var s: f32 = 0.0;
            if (l != 0.0 and l != 1.0) {
                s = (self.v - l) / @min(l, 1.0 - l);
            }

            // Hue remains same

            return Hsl(T).init(
                self.h,
                s,
                l,
            );
        }

        // Formula for HSV -> HWB conversion:
        // https://en.wikipedia.org/wiki/HWB_color_model
        pub fn toHwb(self: Self) Hwb(T) {
            const w = (1 - self.s) * self.v;
            const b = 1 - self.v;
            return Hwb(T).init(self.h, w, b);
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const tol = 0.002;

test "Hsv(f32) toSrgb" {
    const c = Hsv(f32).init(20.0, 0.75, 0.8).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), c.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.400), c.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), c.b, tol);

    // Achromatic
    const gray = Hsv(f32).init(null, 0, 0.5).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), gray.r, tol);
}

test "Hsv(f32) <-> XYZ round-trip" {
    const original = Hsv(f32).init(20.0, 0.75, 0.8);
    const result = Hsv(f32).fromXyz(original.toXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "Hsv(f32) toHsl" {
    const hsl = Hsv(f32).init(20.0, 0.75, 0.8).toHsl();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsl.h.?, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.600), hsl.s, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.500), hsl.l, tol);
}

test "Hsv(f32) toHwb" {
    const hwb = Hsv(f32).init(20.0, 0.75, 0.8).toHwb();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hwb.h.?, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), hwb.w, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), hwb.b, tol);
}
