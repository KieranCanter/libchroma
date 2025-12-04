const std = @import("std");

const Cmyk = @import("color-spaces/Cmyk.zig").Cmyk;
const Hex = @import("color-spaces/Hex.zig").Hex;
const Hsi = @import("color-spaces/Hsi.zig").Hsi;
const Hsl = @import("color-spaces/Hsl.zig").Hsl;
const Hsv = @import("color-spaces/Hsv.zig").Hsv;
const Hwb = @import("color-spaces/Hwb.zig").Hwb;
const Srgb = @import("color-spaces/Srgb.zig").Srgb;
const Xyz = @import("color-spaces/Xyz.zig").Xyz;
const Yxy = @import("color-spaces/Yxy.zig").Yxy;

pub const ColorSpace = enum {
    cmyk,
    hex,
    hsi,
    hsl,
    hsv,
    hwb,
    srgb,
    xyz,
    yxy,
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
    yxy: Yxy,
};

pub const AlphaColor = struct {
    value: Color,
    alpha: f32,
};
