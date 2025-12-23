const assertFloatType = @import("../validation.zig").assertFloatType;

/// Type to hold a CIE XYZ value. The central funnel for converting across the common color spaces
/// like sRGB to the CIE LAB color spaces.
///
/// x: mix of the three CIE RGB curves in [0.0, inf)
/// y: luminance value in [0.0, inf)
/// z: quasi-blue value in [0.0, inf)
pub fn Xyz(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }
    };
}
