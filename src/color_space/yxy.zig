const assertFloatType = @import("../validation.zig").assertFloatType;

const Srgb = @import("rgb/srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold a Yxy value.
///
/// luma: luma value in [0.0, 1.0]
/// x: chroma-x value in [0.0, 1.0]
/// y: chroma-y value in [0.0, 1.0]
pub fn Yxy(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        const Backing = T;

        luma: T,
        x: T,
        y: T,

        pub fn init(luma: T, x: T, y: T) Self {
            return .{ .luma = luma, .x = x, .y = y };
        }

        // Formula for Yxy -> XYZ conversion:
        // http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
        pub fn toXyz(self: Self) Xyz(T) {
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

        // Formula for XYZ -> Yxy conversion:
        // http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
        pub fn fromXyz(xyz: Xyz(T)) Self {
            const sum = xyz.x + xyz.y + xyz.z;

            if (sum == 0) {
                return Yxy(T).init(0.0, 0.0, 0.0);
            }

            // Y (luma) remains the same as y

            // x
            const x = xyz.x / sum;

            // y
            const y = xyz.y / sum;

            return Yxy(T).init(xyz.y, x, y);
        }

        pub fn toSrgb(self: Self) Srgb(T) {
            return self.toXyz().toSrgb();
        }
    };
}
