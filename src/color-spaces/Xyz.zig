const Cmyk = @import("Cmyk.zig").Cmyk;
const Hex = @import("Hex.zig").Hex;
const Hsi = @import("Hsi.zig").Hsi;
const Hsl = @import("Hsl.zig").Hsl;
const Hsv = @import("Hsv.zig").Hsv;
const Hwb = @import("Hwbg.zig").Hsv;
const LinearSrgb = @import("Srgb.zig").LinearSrgb;
const Srgb = @import("Srgb.zig").Srgb;
const Yxy = @import("Yxy.zig").Yxy;

// Matrices for various RGB <-> XYZ conversions with linearized RGB values:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const XYZ_TO_SRGB: [3][3]f32 = .{
    .{ 3.2404542, -1.5371385, -0.4985314 },
    .{ -0.9692660, 1.8760108, 0.0415560 },
    .{ 0.0556434, -0.2040259, 1.0572252 },
};

/// Type to hold a CIE XYZ value. The central funnel for converting across the common color spaces
/// like sRGB to the CIE LAB color spaces.
///
/// x: mix of the three CIE RGB curves in [0.0, 1.0]
/// y: luminance value in [0.0, 1.0]
/// z: quasi-blue value in [0.0, 1.0]
pub const Xyz = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn toSrgb(self: Xyz) Srgb {
        const linear = LinearSrgb{
            .r = self.x * XYZ_TO_SRGB[0][0] + self.y * XYZ_TO_SRGB[0][1] + self.z * XYZ_TO_SRGB[0][2],
            .g = self.x * XYZ_TO_SRGB[1][0] + self.y * XYZ_TO_SRGB[1][1] + self.z * XYZ_TO_SRGB[1][2],
            .b = self.x * XYZ_TO_SRGB[2][0] + self.y * XYZ_TO_SRGB[2][1] + self.z * XYZ_TO_SRGB[2][2],
        };
        return LinearSrgb.toSrgb(linear);
    }

    pub fn toCmyk(self: Xyz) Cmyk {
        return self.toSrgb().toCmyk();
    }

    pub fn toHex(self: Xyz) Hex {
        return self.toSrgb().toHex();
    }

    pub fn toHsi(self: Xyz) Hsi {
        return self.toSrgb().toHsi();
    }

    pub fn toHsl(self: Xyz) Hsl {
        return self.toSrgb().toHsl();
    }

    pub fn toHsv(self: Xyz) Hsv {
        return self.toSrgb().toHsv();
    }

    pub fn toHwb(self: Xyz) Hwb {
        return self.toSrgb().toHwb();
    }

    // Formula for XYZ -> Yxy conversion:
    // http://www.brucelindbloom.com/index.html?Eqn_xyY_to_XYZ.html
    pub fn toYxy(self: Xyz) Yxy {
        const sum = self.x + self.y + self.z;

        if (sum == 0) {
            return Yxy{.luma = 0.0, .x = 0.0, .y = 0.0};
        }

        // Y (luma) remains the same as y

        // x
        const x = self.x / sum;

        // y
        const y = self.y / sum;

        return Yxy{.luma = self.y, .x = x, .y = y};
    }
};
