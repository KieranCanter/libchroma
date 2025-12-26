const assertFloatType = @import("../validation.zig").assertFloatType;

const Hsv = @import("Hsv.zig").Hsv;
const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

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

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toHsl();
        }

        // Formula for HSL -> sRGB conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                return Srgb(T).init(self.l, self.l, self.l);
            }

            const h = self.h.?;
            const chroma = (1.0 - @abs(2 * self.l - 1.0)) * self.s;
            const hprime = @as(u8, @floor(h / 60.0));
            const x = chroma * (1.0 - @abs(@mod(hprime, 2) - 1.0));
            const m = self.l - (chroma / 2.0);

            return switch (hprime) {
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
