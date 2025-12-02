const std = @import("std");

const Cmyk = @import("color-spaces/Cmyk.zig").Cmyk;
const Hex = @import("color-spaces/Hex.zig").Hex;
const Hsl = @import("color-spaces/Hsl.zig").Hsl;
const Hsv = @import("color-spaces/Hsv.zig").Hsv;
const LinearRgb = @import("color-spaces/LinearRgb.zig").LinearRgb;
const Srgb = @import("color-spaces/Srgb.zig").Srgb;
const Xyz = @import("color-spaces/Xyz.zig").Xyz;

pub const ColorSpace = enum {
    cmyk,
    hex,
    hsl,
    hsv,
    linearRgb,
    srgb,
    xyz,
};

pub const ColorValue = union(ColorSpace) {
    cmyk: Cmyk,
    hex: Hex,
    hsl: Hsl,
    hsv: Hsv,
    linearRgb: LinearRgb,
    srgb: Srgb,
    xyz: Xyz,
};

pub const Color = struct {
    value: ColorValue,
    alpha: f64,
};

pub const Canonical = struct {
    value: Xyz,
    alpha: f64,
};

pub fn toCanonical(color: Color) Canonical {
    @compileLog("TODO: Implement `toCanonical()");
}

pub fn fromCanonical(canon: Canonical) Color {
    @compileLog("TODO: Implement `fromCanonical()");
}
