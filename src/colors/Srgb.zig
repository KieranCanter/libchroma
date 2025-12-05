const std = @import("std");

const Cmyk = @import("Cmyk.zig");
const Hex = @import("Hex.zig");
const Hsi = @import("Hsi.zig");
const Hsl = @import("Hsl.zig");
const Hsv = @import("Hsv.zig");
const Hwb = @import("Hwb.zig");
const Xyz = @import("Xyz.zig");
const Yxy = @import("Yxy.zig");

// Matrix for linearizing sRGB during sRGB-> XYZ conversion:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const SRGB_TO_XYZ: [3][3]f32 = .{
    .{ 0.4124564, 0.3575761, 0.1804375 },
    .{ 0.2126729, 0.7151522, 0.0721750 },
    .{ 0.0193339, 0.1191920, 0.9503041 },
};

/// Type to hold a non-linear sRGB value. Generic "RGB" most commonly refers to sRGB.
///
/// r: red value in [0.0, 1.0]
/// g: green value in [0.0, 1.0]
/// b: blue value in [0.0, 1.0]
const Srgb = @This();
r: f32,
g: f32,
b: f32,

/// Type to hold a linearized sRGB value.
///
/// r: red value in [0.0, 1.0]
/// g: green value in [0.0, 1.0]
/// b: blue value in [0.0, 1.0]
pub const LinearSrgb = struct {
    r: f32,
    g: f32,
    b: f32,

    pub fn toSrgb(self: LinearSrgb) Srgb {
        return Srgb{
            .r = linearToGamma(self.r),
            .g = linearToGamma(self.g),
            .b = linearToGamma(self.b),
        };
    }

    // Formulae for sRGB <-> Linear conversions:
    // https://entropymine.com/imageworsener/srgbformula/
    fn linearToGamma(val: f32) f32 {
        if (val <= 0.0031308) return 12.92 * val;
        return 1.055 * std.math.pow(val, 1.0 / 2.4) - 0.055;
    }
};

pub fn toXyz(self: Srgb) Xyz {
    const linear = toLinear(self);
    return Xyz{
        .x = linear.r * SRGB_TO_XYZ[0][0] + linear.g * SRGB_TO_XYZ[0][1] + linear.b * SRGB_TO_XYZ[0][2],
        .y = linear.r * SRGB_TO_XYZ[1][0] + linear.g * SRGB_TO_XYZ[1][1] + linear.b * SRGB_TO_XYZ[1][2],
        .z = linear.r * SRGB_TO_XYZ[2][0] + linear.g * SRGB_TO_XYZ[2][1] + linear.b * SRGB_TO_XYZ[2][2],
    };
}

pub fn toLinear(self: Srgb) LinearSrgb {
    return LinearSrgb{
        .r = gammaToLinear(self.r),
        .g = gammaToLinear(self.g),
        .b = gammaToLinear(self.b),
    };
}

// Formulae for sRGB <-> Linear conversions:
// https://entropymine.com/imageworsener/srgbformula/
fn gammaToLinear(val: f32) f32 {
    if (val <= 0.04045) return val / 12.92;
    return std.math.pow((val + 0.055) / 1.055, 2.4);
}

// Formula for sRGB -> CMYK conversion:
// https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
pub fn toCmyk(self: Srgb) Cmyk {
    const k = @max(self.r, self.g, self.b);

    const c = (1.0 - self.r - k) / (1.0 - k);
    const m = (1.0 - self.g - k) / (1.0 - k);
    const y = (1.0 - self.b - k) / (1.0 - k);

    return Cmyk{ .c = c, .m = m, .y = y, .k = k };
}

pub fn toHex(self: Srgb) Hex {
    const r = @as(u8, self.r * 255.0 + 0.5);
    const g = @as(u8, self.g * 255.0 + 0.5);
    const b = @as(u8, self.b * 255.0 + 0.5);

    return Hex{ .value = (r << 16) | (g << 8) | b };
}

// Formula for sRGB -> HSI conversion:
// https://www.rmuti.ac.th/user/kedkarn/impfile/RGB_to_HSI.pdf
pub fn toHsi(self: Srgb) Hsi {
    const xmax = @max(self.r, self.g, self.b);
    const xmin = @min(self.r, self.g, self.b);
    const chroma = xmax - xmin;

    // Intensity
    const i = (self.r + self.g + self.b) / 3.0;

    // Saturation
    var s: f32 = 0.0;
    if (i != 0) {
        s = 1.0 - (xmin / i);
    }

    // Hue
    var h: ?f32 = null;
    if (chroma != 0) {
        h = self.computeHue(xmin, xmax);
    }

    return Hsi{ .h = h, .s = s, .i = i };
}

// Formula for sRGB -> HSL conversion:
// https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
pub fn toHsl(self: Srgb) Hsl {
    const xmax = @max(self.r, self.g, self.b);
    const xmin = @min(self.r, self.g, self.b);
    const chroma = xmax - xmin;

    // Lightness
    const l = (xmax + xmin) / 2.0;

    // Hue
    var h: ?f32 = null;
    if (chroma != 0) {
        h = self.computeHue(xmin, xmax);
    }

    // Saturation
    var s: f32 = 0.0;
    if (l != 0 and l != 1) {
        s = chroma / (1.0 - @abs(2.0 * l - 1.0));
    }

    return Hsl{ .h = h, .s = s, .l = l };
}

// Formula for sRGB -> HSL conversion:
// https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
pub fn toHsv(self: Srgb) Hsv {
    // Value
    const xmax = @max(self.r, self.g, self.b);
    const xmin = @min(self.r, self.g, self.b);
    const chroma = xmax - xmin;

    // Hue
    var h: ?f32 = null;
    if (chroma != 0) {
        h = self.computeHue(xmin, xmax);
    }

    // Saturation
    var s: f32 = 0.0;
    if (xmax != 0) {
        s = chroma / xmax;
    }

    return Hsv{ .h = h, .s = s, .v = xmax };
}

// Formula for sRGB -> HWB conversion:
// https://www.w3.org/TR/css-color-4/#rgb-to-hwb
pub fn toHwb(self: Srgb) Hwb {
    const xmax = @max(self.r, self.g, self.b);
    const xmin = @min(self.r, self.g, self.b);

    // Whiteness
    const w = xmin;

    // Blackness
    const b = 1.0 - xmax;

    // Hue
    const epsilon: f32 = 1 / 100000; // for floating point error
    var h: ?f32 = null;
    if (w + b >= 1 - epsilon) {
        h = self.computeHue(xmin, xmax);
    }

    return Hwb{ .h = h, .w = w, .b = b };
}

/// Typically, the hue of HSI, HSL, HSV, and HWB is calulcated via an trigonemetric algorithm as
/// such:
///
/// ```zig
/// const numerator = 0.5 * ((self.r - self.g) + (self.r - self.b));
/// const denominator = std.math.sqrt((self.r - self.g) * (self.r - self.g) + (self.r - self.b) * (self.g - self.b));
/// var h = std.math.acos(numerator / denominator) * 180 / std.math.pi;
/// if (self.b > self.g) {
///     h = 360.0 - h;
/// }
/// ```
///
/// or in plaintext:
///
/// ```
/// N = 0.5[(R - G) + (R - B)] = R - ((G + B) / 2)
/// D = sqrt(pow(R - G, 2) + (R - B) * (G - B))
/// Hue = acos(N / D)
/// ```
///
/// To avoid expensive functions like acos() and sqrt(), we can use the max RGB channel and min
/// RGB channel to calculate the hue instead. When we consider that each 60° sector will have a
/// most dominant channel and least dominant channel, the above cosine ratio can be simplified
/// to a linear function, where `C = max(R, G, B) - min(R, G, B)` represents the chroma and the
/// subscript to `Hue` represents the most dominant channel.
///
/// ```
/// Hue_R = 60 * (((G - B) / C) % 6)
/// Hue_G = 60 * ((B - R) / C) + 2)
/// Hue_B = 60 * ((R - B) / C) + 4)
/// ```
///
/// Note:
/// * Each one of ((R, G, B) - (R, G, B) / C) will be in the range [-1, 1]
/// * `Hue_R` represents the 300°-60° sector, so it has no offset, but must be guaranteed to be
/// within positive bounds, thus the modulo is used to ensure this (alternatively you could
/// conditionally check for negativity and add 360°)
/// * `Hue_G` represents the 60°-180° sector, so it is offset by 2 (120°)
/// * `Hue_B` represents the 180°-300° sector, so it is offset by 4 (240°)
fn computeHue(self: Srgb, min_channel: f32, max_channel: f32) f32 {
    const chroma = max_channel - min_channel;
    var h: f32 = 0;
    if (max_channel == self.r) {
        h = 60.0 * @mod((self.g - self.b) / chroma, 6);
    } else if (max_channel == self.g) {
        h = 60.0 * ((self.b - self.r) / chroma + 2.0);
    } else if (max_channel == self.b) {
        h = 60.0 * ((self.r - self.g) / chroma + 4.0);
    } else {
        unreachable;
    }

    return h;
}

pub fn toYxy(self: Srgb) Yxy {
    return self.toXyz().toYxy();
}
