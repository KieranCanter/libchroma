const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold a CMYK value.
///
/// c: cyan value in [0.0, 1.0]
/// m: magenta value in [0.0, 1.0]
/// y: yellow value in [0.0, 1.0]
/// k: black value in [0.0, 1.0]
pub const Cmyk = struct {
    c: f32,
    m: f32,
    y: f32,
    k: f32,

    pub fn toXyz(self: Cmyk) Xyz {
        return self.toSrgb().toXyz();
    }

    // Formula for CMYK -> sRGB:
    // https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
    pub fn toSrgb(self: Cmyk) Srgb {
        const r = (1 - self.c) * (1 - self.k);
        const g = (1 - self.m) * (1 - self.k);
        const b = (1 - self.y) * (1 - self.k);

        return Srgb{ .r = r, .g = g, .b = b };
    }
};
