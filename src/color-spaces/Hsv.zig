const Hsl = @import("Hsl.zig").Hsl;
const Hwb = @import("Hwb.zig").Hwb;
const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold an HSV value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// v: value value in [0.0, 1.0]
pub const Hsv = struct {
    h: ?f32,
    s: f32,
    v: f32,

    pub fn toXyz(self: Hsv) Xyz {
        return self.toSrgb().toXyz();
    }

    // Formula for HSV -> sRGB conversion:
    // https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_RGB
    pub fn toSrgb(self: Hsv) Srgb {
        if (self.h == null) {
            return Srgb{ .r = self.l, .g = self.l, .b = self.l };
        }

        const h = self.h.?;
        const chroma = self.v * self.s;
        const hprime = @as(u8, @floor(h / 60.0));
        const x = chroma * (1.0 - @abs(@mod(hprime, 2) - 1.0));
        const m = self.v - chroma;

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

    // Formula for HSV -> HSL conversion:
    // https://en.wikipedia.org/wiki/HSL_and_HSV#HSV_to_HSL
    pub fn toHsl(self: Hsv) Hsl {
        // Lightness
        const l = self.v * (1.0 - (self.s / 2.0));

        // Saturation
        var s: f32 = 0.0;
        if (l != 0.0 and l != 1.0) {
            s = (self.v - l) / @min(l, 1.0 - l);
        }

        // Hue remains same

        return Hsl{
            .h = self.h,
            .s = s,
            .l = l,
        };
    }

    // Formula for HSV -> HWB conversion:
    // https://en.wikipedia.org/wiki/HWB_color_model
    pub fn toHwb(self: Hsv) Hwb {
        const w = (1 - self.s) * self.v;
        const b = 1 - self.v;
        return Hwb{ .h = self.h, .w = w, .b = b };
    }
};
