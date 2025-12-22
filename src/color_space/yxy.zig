const Srgb = @import("srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold a Yxy value.
///
/// luma: luma value in [0.0, 1.0]
/// x: chroma-x value in [0.0, 1.0]
/// y: chroma-y value in [0.0, 1.0]
pub fn Yxy(comptime T: type) type {
    return struct {
        const Self = @This();

        luma: T,
        x: T,
        y: T,

        // Formula for Yxy -> XYZ conversion:
        // http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
        pub fn toXyz(self: Self) @TypeOf(Xyz(T)) {
            if (self.y == 0) {
                return Xyz(T).init(0, 0, 0);
            }

            // X
            const X = (self.x * self.luma) / self.y;

            // Y remains the same as luma

            // Z
            const Z = ((1.0 - self.x - self.y) * self.luma) / self.y;

            return Xyz(T).init(X, self.y, Z);
        }

        pub fn toSrgb(self: Self) @TypeOf(Srgb(T)) {
            return self.toXyz().toSrgb();
        }
    };
}
