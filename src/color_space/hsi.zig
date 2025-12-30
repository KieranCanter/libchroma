const assertFloatType = @import("../validation.zig").assertFloatType;

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
            const hprime = @as(u8, @floor(h / 60.0));
            const z = 1.0 - @abs(@mod(hprime, 2) - 1.0);
            const chroma = (3.0 * self.i * self.s) / (1.0 + z);
            const x = chroma * z;
            const m = self.i * (1.0 - self.s);

            return switch (hprime) {
                0, 6 => Srgb.init(chroma + m, x + m, m),
                1 => Srgb.init(x + m, chroma + m, m),
                2 => Srgb.init(m, chroma + m, x + m),
                3 => Srgb.init(m, x + m, chroma + m),
                4 => Srgb.init(x + m, m, chroma + m),
                5 => Srgb.init(chroma + m, m, x + m),
                else => unreachable,
            };
        }
    };
}
