const Srgb = @import("Srgb.zig").Srgb;
const Xyz = @import("Xyz.zig").Xyz;

/// Type to hold a Hex value of three bytes equivalent to an sRGB value.
///
/// value: three-byte unsigned integer in the form of 0xRRGGBB
pub const Hex = struct {
    value: u24,

    pub fn toXyz(self: Hex) Xyz {
        return self.toSrgb().toXyz();
    }

    pub fn toSrgb(self: Hex) Srgb {
        const r = @as(f32, (self.value >> 16) & 0xFF) / 255.0;
        const g = @as(f32, (self.value >> 8) & 0xFF) / 255.0;
        const b = @as(f32, self.value & 0xFF) / 255.0;

        return Srgb{ .r = r, .g = g, .b = b };
    }
};
