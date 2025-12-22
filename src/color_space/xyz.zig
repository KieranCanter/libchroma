const Cmyk = @import("cmyk.zig").Cmyk;
const Hex = @import("srgb.zig").HexSrgb;
const Hsi = @import("hsi.zig").Hsi;
const Hsl = @import("hsl.zig").Hsl;
const Hsv = @import("hsv.zig").Hsv;
const Hwb = @import("hwb.zig").Hwb;
const LinearSrgb = @import("srgb.zig").LinearSrgb;
const Srgb = @import("srgb.zig").Srgb;
const Yxy = @import("yxy.zig").Yxy;

/// Type to hold a CIE XYZ value. The central funnel for converting across the common color spaces
/// like sRGB to the CIE LAB color spaces.
///
/// x: mix of the three CIE RGB curves in [0.0, 1.0]
/// y: luminance value in [0.0, 1.0]
/// z: quasi-blue value in [0.0, 1.0]
pub fn Xyz(comptime T: type) type {
    return struct {
        const Self = @This();

        x: T,
        y: T,
        z: T,

        pub fn toCmyk(self: Self) @TypeOf(Cmyk(T)) {
            return self.toSrgb().toCmyk();
        }

        pub fn toHex(self: Self) @TypeOf(Hex(T)) {
            return self.toSrgb().toHex();
        }

        pub fn toHsi(self: Self) @TypeOf(Hsi(T)) {
            return self.toSrgb().toHsi();
        }

        pub fn toHsl(self: Self) @TypeOf(Hsl(T)) {
            return self.toSrgb().toHsl();
        }

        pub fn toHsv(self: Self) @TypeOf(Hsv(T)) {
            return self.toSrgb().toHsv();
        }

        pub fn toHwb(self: Self) @TypeOf(Hwb(T)) {
            return self.toSrgb().toHwb();
        }

        // Formula for XYZ -> Yxy conversion:
        // http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
        pub fn toYxy(self: Self) @TypeOf(Yxy(T)) {
            const sum = self.x + self.y + self.z;

            if (sum == 0) {
                return Yxy(T).init(0.0, 0.0, 0.0);
            }

            // Y (luma) remains the same as y

            // x
            const x = self.x / sum;

            // y
            const y = self.y / sum;

            return Yxy(T).init(self.y, x, y);
        }
    };
}
