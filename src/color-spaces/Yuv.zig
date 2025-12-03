const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold a YUV value.
///
/// y: luma value in [0.0, 1.0]
/// u: chroma-x value in [0.0, 1.0]
/// v: chroma-y value in [0.0, 1.0]
pub const Yuv = struct {
    y: f32,
    u: f32,
    v: f32,

    pub fn toXyz(self: Yuv) Xyz {
        return self.toSrgb().toXyz();
    }

    pub fn toSrgb(self: Yuv) Srgb {}
};
