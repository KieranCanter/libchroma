const Srgb = @import("Srgb.zig");
const Xyz = @import("Xyz.zig");

/// Type to hold a Yxy value.
///
/// luma: luma value in [0.0, 1.0]
/// x: chroma-x value in [0.0, 1.0]
/// y: chroma-y value in [0.0, 1.0]
const Yxy = @This();
luma: f32,
x: f32,
y: f32,

// Formula for Yxy -> XYZ conversion:
// http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
pub fn toXyz(self: Yxy) Xyz {
    if (self.y == 0) {
        return Xyz{ .x = 0, .y = 0, .z = 0 };
    }

    // X
    const X = (self.x * self.luma) / self.y;

    // Y remains the same as luma

    // Z
    const Z = ((1.0 - self.x - self.y) * self.luma) / self.y;

    return Xyz{ .x = X, .y = self.y, .z = Z };
}

pub fn toSrgb(self: Yxy) Srgb {
    return self.toXyz().toSrgb();
}
