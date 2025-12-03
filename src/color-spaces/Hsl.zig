const Hsv = @import("Hsv.zig").Hsv;
const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold an HSL value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// l: lightness value in [0.0, 1.0]
pub const Hsl = struct {
    h: ?f32,
    s: f32,
    l: f32,

    pub fn toXyz(self: Hsl) Xyz {
        return self.toSrgb().toXyz();
    }

    // Formula for HSL -> sRGB conversion:
    // https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB
    pub fn toSrgb(self: Hsl) Srgb {
        if (self.h == null) {
            return Srgb{ .r = self.l, .g = self.l, .b = self.l };
        }

        const h = self.h.?;
        const chroma = (1.0 - @abs(2 * self.l - 1.0)) * self.s;
        const hprime = @as(u8, @floor(h / 60.0));
        const x = chroma * (1.0 - @abs(@mod(hprime, 2) - 1.0));
        const m = self.l - (chroma / 2.0);

        return switch (hprime) {
            0, 6 => Srgb{ .r = chroma + m, .g = x + m, .b = m },
            1 => Srgb{ .r = x + m, .g = chroma + m, .b = m },
            2 => Srgb{ .r = m, .g = chroma + m, .b = x + m },
            3 => Srgb{ .r = m, .g = x + m, .b = chroma + m },
            4 => Srgb{ .r = x + m, .g = m, .b = chroma + m },
            5 => Srgb{ .r = chroma + m, .g = m, .b = x + m },
            else => unreachable,
        };
    }

    // Formula for HSL -> HSV conversion:
    // https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_HSV
    pub fn toHsv(self: Hsl) Hsv {
        // Value
        const v = self.l + self.s * @min(self.l, 1 - self.l);

        // Saturation
        var s: f32 = 0.0;
        if (v != 0.0) {
            s = 2.0 * (1.0 - (self.l / v));
        }

        // Hue remains same

        return Hsv{
            .h = self.h,
            .s = s,
            .v = v,
        };
    }
};
