const Hsl = @import("Hsl.zig");
const Hsv = @import("Hsv.zig");
const Srgb = @import("Srgb.zig");
const Xyz = @import("Xyz.zig");

/// Type to hold an HSI value.
///
/// h: hue value in [0.0, 360.0] or null when saturation is 0
/// s: saturation value in [0.0, 1.0]
/// i: intensity value in [0.0, 1.0]
const Hsi = @This();
h: ?f32,
s: f32,
i: f32,

pub fn toXyz(self: Hsi) Xyz {
    return self.toSrgb().toXyz();
}

// Formula for HSI -> sRGB conversion:
// https://en.wikipedia.org/wiki/HSL_and_HSV#HSI_to_RGB
pub fn toSrgb(self: Hsi) Srgb {
    if (self.h == null) {
        return Srgb{ .r = self.i, .g = self.i, .b = self.i };
    }

    const h = self.h.?;
    const hprime = @as(u8, @floor(h / 60.0));
    const z = 1.0 - @abs(@mod(hprime, 2) - 1.0);
    const chroma = (3.0 * self.i * self.s) / (1.0 + z);
    const x = chroma * z;
    const m = self.i * (1.0 - self.s);

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
