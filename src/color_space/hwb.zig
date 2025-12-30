const assertFloatType = @import("../validation.zig").assertFloatType;

const Hsv = @import("hsv.zig").Hsv;
const Srgb = @import("rgb/srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold an HWB value.
///
/// h: hue value in [0.0, 360.0] or null when white + black >= 1
/// w: whiteness value in [0.0, 1.0]
/// b: blackness value in [0.0, 1.0]
pub fn Hwb(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        h: ?T,
        w: T,
        b: T,

        pub fn init(h: ?T, w: T, b: T) Self {
            return .{ .h = h, .w = w, .b = b };
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toHwb();
        }

        // Formula for HWB -> sRGB conversion:
        // https://alvyray.com/Papers/CG/HWB_JGTv208.pdf
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                const gray = 1.0 - self.b;
                return Srgb(T).init(gray, gray, gray);
            }

            const h = self.h.?;
            const v = 1.0 - self.b;
            const hprime = @as(u8, @floor(h / 60.0));
            var f = (h / 60.0) - hprime;

            if (hprime & 1) { // hprime is odd
                f = 1 - f;
            }

            const n = self.w + f * (v - self.w); // linear interpolation between self.w and v

            return switch (hprime) {
                0, 6 => Srgb(T).init(v, n, self.w),
                1 => Srgb(T).init(n, v, self.w),
                2 => Srgb(T).init(self.w, v, n),
                3 => Srgb(T).init(self.w, n, v),
                4 => Srgb(T).init(n, self.w, v),
                5 => Srgb(T).init(v, self.w, n),
                else => unreachable,
            };
        }

        // Formula for HWB -> HSV conversion:
        // https://en.wikipedia.org/wiki/HWB_color_model
        pub fn toHsv(self: Self) Hsv(T) {
            const s = 1 - (self.w / (1 - self.b));
            const v = 1 - self.b;
            return Hsv(T).init(self.h, s, v);
        }
    };
}
