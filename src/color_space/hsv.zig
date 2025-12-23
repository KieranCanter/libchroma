const assertFloatType = @import("../validation.zig").assertFloatType;

const Hsl = @import("hsl.zig").Hsl;
const Hwb = @import("hwb.zig").Hwb;
const Srgb = @import("srgb.zig").Srgb;
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

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toHsl();
        }

        // Formula for HSV -> sRGB conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                return Srgb(T).init(self.l, self.l, self.l);
            }

            const h = self.h.?;
            const chroma = self.v * self.s;
            const hprime = @as(u8, @floor(h / 60.0));
            const x = chroma * (1.0 - @abs(@mod(hprime, 2) - 1.0));
            const m = self.v - chroma;

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
