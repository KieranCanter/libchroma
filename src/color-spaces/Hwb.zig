const Hsv = @import("Hsv.zig").Hsv;
const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold an HWB value.
///
/// h: hue value in [0.0, 360.0] or null when white + black >= 1
/// w: whiteness value in [0.0, 1.0]
/// b: blackness value in [0.0, 1.0]
pub const Hwb = struct {
    h: ?f32,
    w: f32,
    b: f32,

    pub fn toXyz(self: Hwb) Xyz {
        return self.toSrgb().toXyz();
    }

    // Formula for HWB -> sRGB conversion:
    // https://alvyray.com/Papers/CG/HWB_JGTv208.pdf
    pub fn toSrgb(self: Hwb) Srgb {
        if (self.h == null) {
            const gray = 1.0 - self.b;
            return Srgb{ .r = gray, .g = gray, .b = gray };
        }

        const h = self.h.?;
        const v = 1.0 - self.b;
        const hprime = @as(u8, @floor(h / 60.0));
        var f = (h / 60.0) - hprime;

        if (hprime & 1) { // hprime is odd
            f = 1 - f;
        }

        const n = self.w + f * (v - self.w); // linear interpolation between self.w and v

        return switch (hprime) {
            0, 6 => Srgb{ .r = v, .g = n, .b = self.w },
            1 => Srgb{ .r = n, .g = v, .b = self.w },
            2 => Srgb{ .r = self.w, .g = v, .b = n },
            3 => Srgb{ .r = self.w, .g = n, .b = v },
            4 => Srgb{ .r = n, .g = self.w, .b = v },
            5 => Srgb{ .r = v, .g = self.w, .b = n },
            else => unreachable,
        };
    }

    // Formula for HWB -> HSV conversion:
    // https://en.wikipedia.org/wiki/HWB_color_model
    pub fn toHsv(self: Hwb) Hsv {
        const s = 1 - (self.w / (1 - self.b));
        const v = 1 - self.b;
        return Hsv{ .h = self.h, .s = s, .v = v };
    }
};
