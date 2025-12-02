const std = @import("std");
const LinearRgb = @import("LinearRgb.zig").LinearRgb;
const Xyz = @import("Xyz.zig").Xyz;

const SRGB_TO_XYZ: [3][3]f64 = .{
    .{ 0.4124564, 0.3575761, 0.1804375 },
    .{ 0.2126729, 0.7151522, 0.0721750 },
    .{ 0.0193339, 0.1191920, 0.9503041 },
};

const XYZ_TO_SRGB: [3][3]f64 = .{
    .{ 3.2404542, -1.5371385, -0.4985314 },
    .{ -0.9692660, 1.8760108, 0.0415560 },
    .{ 0.0556434, -0.2040259, 1.0572252 },
};

pub const Srgb = struct {
    r: f64,
    g: f64,
    b: f64,

    // Matrices for various RGB <-> XYZ conversions with linearized RGB values:
    // http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
    pub fn toXyz(self: Srgb) Xyz {
        const linear = toLinearRgb(self);
        return Xyz{
            .x = linear.r * SRGB_TO_XYZ[0][0] + linear.g * SRGB_TO_XYZ[0][1] + linear.b * SRGB_TO_XYZ[0][2],
            .y = linear.r * SRGB_TO_XYZ[1][0] + linear.g * SRGB_TO_XYZ[1][1] + linear.b * SRGB_TO_XYZ[1][2],
            .z = linear.r * SRGB_TO_XYZ[2][0] + linear.g * SRGB_TO_XYZ[2][1] + linear.b * SRGB_TO_XYZ[2][2],
        };
    }

    pub fn fromXyz(xyz: Xyz) Srgb {
        const linear = LinearRgb{
            .r = xyz.x * XYZ_TO_SRGB[0][0] + xyz.y * XYZ_TO_SRGB[0][1] + xyz.z * XYZ_TO_SRGB[0][2],
            .g = xyz.x * XYZ_TO_SRGB[1][0] + xyz.y * XYZ_TO_SRGB[1][1] + xyz.z * XYZ_TO_SRGB[1][2],
            .b = xyz.x * XYZ_TO_SRGB[2][0] + xyz.y * XYZ_TO_SRGB[2][1] + xyz.z * XYZ_TO_SRGB[2][2],
        };
        return fromLinearRgb(linear);
    }

    pub fn toLinearRgb(self: Srgb) LinearRgb {
        return LinearRgb{
            .r = gammaToLinear(self.r),
            .g = gammaToLinear(self.g),
            .b = gammaToLinear(self.b),
        };
    }

    pub fn fromLinearRgb(linear: LinearRgb) Srgb {
        return Srgb{
            .r = linearToGamma(linear.r),
            .g = linearToGamma(linear.g),
            .b = linearToGamma(linear.b),
        };
    }

    // Formulae for sRGB <-> Linear conversions:
    // https://entropymine.com/imageworsener/srgbformula/
    fn gammaToLinear(val: f64) f64 {
        if (val <= 0.04045) return val / 12.92;
        return std.math.pow((val + 0.055) / 1.055, 2.4);
    }

    fn linearToGamma(val: f64) f64 {
        if (val <= 0.0031308) return 12.92 * val;
        return 1.055 * std.math.pow(val, 1.0 / 2.4) - 0.055;
    }
};
