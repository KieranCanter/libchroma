// C ABI bridge for libchroma.
// Maps between C-compatible extern types and internal Zig color types.

const std = @import("std");
const lib = @import("../lib.zig");

const Cmyk = lib.Cmyk;
const Hsi = lib.Hsi;
const Hsl = lib.Hsl;
const Hsv = lib.Hsv;
const Hwb = lib.Hwb;
const Lab = lib.Lab;
const Lch = lib.Lch;
const Oklab = lib.Oklab;
const Oklch = lib.Oklch;
const Xyz = lib.Xyz;
const Yxy = lib.Yxy;
const Srgb = lib.Srgb;
const LinearSrgb = lib.LinearSrgb;
const DisplayP3 = lib.DisplayP3;
const LinearDisplayP3 = lib.LinearDisplayP3;
const Rec2020 = lib.Rec2020;
const Rec2020Scene = lib.Rec2020Scene;
const LinearRec2020 = lib.LinearRec2020;

const HUE_NONE = std.math.nan(f32);

fn hueToC(h: ?f32) f32 {
    return h orelse HUE_NONE;
}

fn hueFromC(h: f32) ?f32 {
    return if (std.math.isNan(h)) null else h;
}

// -- C ABI types (must match include/chroma.h layout) --

pub const Space = enum(c_int) {
    srgb,
    srgb_u8,
    linear_srgb,
    display_p3,
    linear_display_p3,
    rec2020,
    rec2020_scene,
    linear_rec2020,
    hsl,
    hsv,
    hwb,
    hsi,
    cmyk,
    xyz,
    yxy,
    lab,
    lch,
    oklab,
    oklch,
};

const CRgb = extern struct { r: f32, g: f32, b: f32 };
const CRgbU8 = extern struct { r: u8, g: u8, b: u8 };
const CHsl = extern struct { h: f32, s: f32, l: f32 };
const CHsv = extern struct { h: f32, s: f32, v: f32 };
const CHwb = extern struct { h: f32, w: f32, b: f32 };
const CHsi = extern struct { h: f32, s: f32, i: f32 };
const CCmyk = extern struct { c: f32, m: f32, y: f32, k: f32 };
const CXyz = extern struct { x: f32, y: f32, z: f32 };
const CYxy = extern struct { luma: f32, x: f32, y: f32 };
const CLab = extern struct { l: f32, a: f32, b: f32 };
const CLch = extern struct { l: f32, c: f32, h: f32 };

const ColorData = extern union {
    srgb: CRgb,
    srgb_u8: CRgbU8,
    linear_srgb: CRgb,
    display_p3: CRgb,
    linear_display_p3: CRgb,
    rec2020: CRgb,
    rec2020_scene: CRgb,
    linear_rec2020: CRgb,
    hsl: CHsl,
    hsv: CHsv,
    hwb: CHwb,
    hsi: CHsi,
    cmyk: CCmyk,
    xyz: CXyz,
    yxy: CYxy,
    lab: CLab,
    lch: CLch,
    oklab: CLab,
    oklch: CLch,
};

pub const Color = extern struct {
    space: Space,
    alpha: f32,
    data: ColorData,
};

// -- Unpack: C color -> Zig Xyz(f32) --

fn toXyz(color: Color) Xyz(f32) {
    return switch (color.space) {
        .srgb => Srgb(f32).init(color.data.srgb.r, color.data.srgb.g, color.data.srgb.b).toXyz(),
        .srgb_u8 => Srgb(u8).init(color.data.srgb_u8.r, color.data.srgb_u8.g, color.data.srgb_u8.b).toXyz(),
        .linear_srgb => LinearSrgb(f32).init(color.data.linear_srgb.r, color.data.linear_srgb.g, color.data.linear_srgb.b).toXyz(),
        .display_p3 => DisplayP3(f32).init(color.data.display_p3.r, color.data.display_p3.g, color.data.display_p3.b).toXyz(),
        .linear_display_p3 => LinearDisplayP3(f32).init(color.data.linear_display_p3.r, color.data.linear_display_p3.g, color.data.linear_display_p3.b).toXyz(),
        .rec2020 => Rec2020(f32).init(color.data.rec2020.r, color.data.rec2020.g, color.data.rec2020.b).toXyz(),
        .rec2020_scene => Rec2020Scene(f32).init(color.data.rec2020_scene.r, color.data.rec2020_scene.g, color.data.rec2020_scene.b).toXyz(),
        .linear_rec2020 => LinearRec2020(f32).init(color.data.linear_rec2020.r, color.data.linear_rec2020.g, color.data.linear_rec2020.b).toXyz(),
        .hsl => Hsl(f32).init(hueFromC(color.data.hsl.h), color.data.hsl.s, color.data.hsl.l).toXyz(),
        .hsv => Hsv(f32).init(hueFromC(color.data.hsv.h), color.data.hsv.s, color.data.hsv.v).toXyz(),
        .hwb => Hwb(f32).init(hueFromC(color.data.hwb.h), color.data.hwb.w, color.data.hwb.b).toXyz(),
        .hsi => Hsi(f32).init(hueFromC(color.data.hsi.h), color.data.hsi.s, color.data.hsi.i).toXyz(),
        .cmyk => Cmyk(f32).init(color.data.cmyk.c, color.data.cmyk.m, color.data.cmyk.y, color.data.cmyk.k).toXyz(),
        .xyz => Xyz(f32).init(color.data.xyz.x, color.data.xyz.y, color.data.xyz.z),
        .yxy => Yxy(f32).init(color.data.yxy.luma, color.data.yxy.x, color.data.yxy.y).toXyz(),
        .lab => Lab(f32).init(color.data.lab.l, color.data.lab.a, color.data.lab.b).toXyz(),
        .lch => Lch(f32).init(color.data.lch.l, color.data.lch.c, hueFromC(color.data.lch.h)).toXyz(),
        .oklab => Oklab(f32).init(color.data.oklab.l, color.data.oklab.a, color.data.oklab.b).toXyz(),
        .oklch => Oklch(f32).init(color.data.oklch.l, color.data.oklch.c, hueFromC(color.data.oklch.h)).toXyz(),
    };
}

// -- Pack: Zig Xyz(f32) -> C color data --

fn fromXyz(xyz: Xyz(f32), alpha: f32, space: Space) Color {
    return .{ .space = space, .alpha = alpha, .data = switch (space) {
        .srgb => blk: {
            const c = Srgb(f32).fromXyz(xyz);
            break :blk .{ .srgb = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .srgb_u8 => blk: {
            const c = Srgb(u8).fromXyz(xyz);
            break :blk .{ .srgb_u8 = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .linear_srgb => blk: {
            const c = LinearSrgb(f32).fromXyz(xyz);
            break :blk .{ .linear_srgb = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .display_p3 => blk: {
            const c = DisplayP3(f32).fromXyz(xyz);
            break :blk .{ .display_p3 = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .linear_display_p3 => blk: {
            const c = LinearDisplayP3(f32).fromXyz(xyz);
            break :blk .{ .linear_display_p3 = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .rec2020 => blk: {
            const c = Rec2020(f32).fromXyz(xyz);
            break :blk .{ .rec2020 = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .rec2020_scene => blk: {
            const c = Rec2020Scene(f32).fromXyz(xyz);
            break :blk .{ .rec2020_scene = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .linear_rec2020 => blk: {
            const c = LinearRec2020(f32).fromXyz(xyz);
            break :blk .{ .linear_rec2020 = .{ .r = c.r, .g = c.g, .b = c.b } };
        },
        .hsl => blk: {
            const c = Hsl(f32).fromXyz(xyz);
            break :blk .{ .hsl = .{ .h = hueToC(c.h), .s = c.s, .l = c.l } };
        },
        .hsv => blk: {
            const c = Hsv(f32).fromXyz(xyz);
            break :blk .{ .hsv = .{ .h = hueToC(c.h), .s = c.s, .v = c.v } };
        },
        .hwb => blk: {
            const c = Hwb(f32).fromXyz(xyz);
            break :blk .{ .hwb = .{ .h = hueToC(c.h), .w = c.w, .b = c.b } };
        },
        .hsi => blk: {
            const c = Hsi(f32).fromXyz(xyz);
            break :blk .{ .hsi = .{ .h = hueToC(c.h), .s = c.s, .i = c.i } };
        },
        .cmyk => blk: {
            const c = Cmyk(f32).fromXyz(xyz);
            break :blk .{ .cmyk = .{ .c = c.c, .m = c.m, .y = c.y, .k = c.k } };
        },
        .xyz => .{ .xyz = .{ .x = xyz.x, .y = xyz.y, .z = xyz.z } },
        .yxy => blk: {
            const c = Yxy(f32).fromXyz(xyz);
            break :blk .{ .yxy = .{ .luma = c.luma, .x = c.x, .y = c.y } };
        },
        .lab => blk: {
            const c = Lab(f32).fromXyz(xyz);
            break :blk .{ .lab = .{ .l = c.l, .a = c.a, .b = c.b } };
        },
        .lch => blk: {
            const c = Lch(f32).fromXyz(xyz);
            break :blk .{ .lch = .{ .l = c.l, .c = c.c, .h = hueToC(c.h) } };
        },
        .oklab => blk: {
            const c = Oklab(f32).fromXyz(xyz);
            break :blk .{ .oklab = .{ .l = c.l, .a = c.a, .b = c.b } };
        },
        .oklch => blk: {
            const c = Oklch(f32).fromXyz(xyz);
            break :blk .{ .oklch = .{ .l = c.l, .c = c.c, .h = hueToC(c.h) } };
        },
    } };
}

// -- Exported C API --

export fn chroma_convert(src: Color, dst_space: Space) Color {
    const xyz = toXyz(src);
    return fromXyz(xyz, src.alpha, dst_space);
}

// ============================================================================
// TESTS
// ============================================================================

test "chroma_convert srgb -> hsl" {
    const src = Color{
        .space = .srgb,
        .alpha = 0.5,
        .data = .{ .srgb = .{ .r = 0.8, .g = 0.4, .b = 0.2 } },
    };
    const dst = chroma_convert(src, .hsl);
    const tol: f32 = 0.002;

    std.debug.assert(dst.space == .hsl);
    std.debug.assert(@abs(dst.data.hsl.h - 20.0) < tol);
    std.debug.assert(@abs(dst.data.hsl.s - 0.6) < tol);
    std.debug.assert(@abs(dst.data.hsl.l - 0.5) < tol);
    std.debug.assert(@abs(dst.alpha - 0.5) < tol);
}

test "chroma_convert hsl -> oklab" {
    const src = Color{
        .space = .hsl,
        .alpha = 1.0,
        .data = .{ .hsl = .{ .h = 20.0, .s = 0.6, .l = 0.5 } },
    };
    const dst = chroma_convert(src, .oklab);
    std.debug.assert(dst.space == .oklab);
    std.debug.assert(dst.data.oklab.l > 0.0 and dst.data.oklab.l < 1.0);
}

test "chroma_convert achromatic hue -> NaN" {
    const src = Color{
        .space = .srgb,
        .alpha = 1.0,
        .data = .{ .srgb = .{ .r = 0.5, .g = 0.5, .b = 0.5 } },
    };
    const dst = chroma_convert(src, .hsl);
    std.debug.assert(std.math.isNan(dst.data.hsl.h));
}

test "chroma_convert srgb_u8 -> lab" {
    const src = Color{
        .space = .srgb_u8,
        .alpha = 1.0,
        .data = .{ .srgb_u8 = .{ .r = 200, .g = 100, .b = 50 } },
    };
    const dst = chroma_convert(src, .lab);
    std.debug.assert(dst.space == .lab);
    std.debug.assert(dst.data.lab.l > 50.0 and dst.data.lab.l < 60.0);
}

test "chroma_convert round-trip srgb -> oklch -> srgb" {
    const original = Color{
        .space = .srgb,
        .alpha = 0.75,
        .data = .{ .srgb = .{ .r = 0.8, .g = 0.4, .b = 0.2 } },
    };
    const oklch = chroma_convert(original, .oklch);
    const result = chroma_convert(oklch, .srgb);
    const tol: f32 = 0.002;

    std.debug.assert(@abs(result.data.srgb.r - 0.8) < tol);
    std.debug.assert(@abs(result.data.srgb.g - 0.4) < tol);
    std.debug.assert(@abs(result.data.srgb.b - 0.2) < tol);
    std.debug.assert(@abs(result.alpha - 0.75) < tol);
}
