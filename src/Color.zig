const std = @import("std");

const Cmyk = @import("color-spaces/Cmyk.zig").Cmyk;
const Hex = @import("color-spaces/Hex.zig").Hex;
const Hsi = @import("color-spaces/Hsi.zig").Hsi;
const Hsl = @import("color-spaces/Hsl.zig").Hsl;
const Hsv = @import("color-spaces/Hsv.zig").Hsv;
const Hwb = @import("color-spaces/Hwb.zig").Hwb;
const Srgb = @import("color-spaces/Srgb.zig").Srgb;
const Xyz = @import("color-spaces/Xyz.zig").Xyz;
const Yiq = @import("color-spaces/Yiq.zig").Yiq;
const Yuv = @import("color-spaces/Yuv.zig").Yuv;

pub const ColorSpace = enum {
    cmyk,
    hex,
    hsi,
    hsl,
    hsv,
    hwb,
    srgb,
    xyz,
    yiq,
    yuv,
};

pub const Color= union(ColorSpace) {
    cmyk: Cmyk,
    hex: Hex,
    hsi: Hsi,
    hsl: Hsl,
    hsv: Hsv,
    hwb: Hwb,
    srgb: Srgb,
    xyz: Xyz,
    yiq: Yiq,
    yuv: Yuv,
};

pub const AlphaColor = struct {
    value: Color,
    alpha: f32,
};
