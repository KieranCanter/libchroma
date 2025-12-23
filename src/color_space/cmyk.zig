const assertFloatType = @import("../validation.zig").assertFloatType;

const Srgb = @import("srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold a CMYK value.
///
/// c: cyan value in [0.0, 1.0]
/// m: magenta value in [0.0, 1.0]
/// y: yellow value in [0.0, 1.0]
/// k: black value in [0.0, 1.0]
pub fn Cmyk(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        c: T,
        m: T,
        y: T,
        k: T,

        pub fn init(c: T, m: T, y: T, k: T) Self {
            return .{ .c = c, .m = m, .y = y, .k = k };
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toCmyk();
        }

        // Formula for CMYK -> sRGB conversion:
        // https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
        pub fn toSrgb(self: Self) @TypeOf(Srgb(T)) {
            const r = (1 - self.c) * (1 - self.k);
            const g = (1 - self.m) * (1 - self.k);
            const b = (1 - self.y) * (1 - self.k);

            return Srgb(T).init(r, g, b);
        }
    };
}
