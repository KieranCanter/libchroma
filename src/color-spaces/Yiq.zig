const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold a YIQ value.
///
/// y: luma value in [0.0, 1.0]
/// i: in-phase value in [0.0, 1.0]
/// q: quadrature value in [0.0, 1.0]
pub const Yiq = struct {
    y: f32,
    i: f32,
    q: f32,

    pub fn toXyz(self: Yiq) Xyz {
        return self.toSrgb().toXyz();
    }

    pub fn toSrgb(self: Yiq) Srgb {}
};
