// C ABI bridge for libchroma.
// Maps between C-compatible extern types and internal Zig color types.

const std = @import("std");
const lib = @import("../lib.zig");
const color = lib.color;

const HUE_NONE = std.math.nan(f32);

fn hueToC(h: ?f32) f32 {
    return h orelse HUE_NONE;
}

fn hueFromC(h: f32) ?f32 {
    return if (std.math.isNan(h)) null else h;
}

// C ABI types (must match include/chroma.h layout)

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

// C Space <-> internal Space mapping

fn toInternalSpace(s: Space) color.Space {
    return switch (s) {
        .srgb, .srgb_u8 => .srgb,
        .linear_srgb => .linear_srgb,
        .display_p3 => .display_p3,
        .linear_display_p3 => .linear_display_p3,
        .rec2020 => .rec2020,
        .rec2020_scene => .rec2020scene,
        .linear_rec2020 => .linear_rec2020,
        .hsl => .hsl,
        .hsv => .hsv,
        .hwb => .hwb,
        .hsi => .hsi,
        .cmyk => .cmyk,
        .xyz => .cie_xyz,
        .yxy => .cie_yxy,
        .lab => .cie_lab,
        .lch => .cie_lch,
        .oklab => .oklab,
        .oklch => .oklch,
    };
}

// Unpack: C Color -> internal Color

fn unpack(c: Color) color.Color {
    return switch (c.space) {
        .srgb => .{ .srgb = .{ .r = c.data.srgb.r, .g = c.data.srgb.g, .b = c.data.srgb.b } },
        .srgb_u8 => blk: {
            // Convert u8 to f32 sRGB
            const s = lib.Srgb(u8).init(c.data.srgb_u8.r, c.data.srgb_u8.g, c.data.srgb_u8.b);
            const f = lib.convert(s, lib.Srgb(f32));
            break :blk .{ .srgb = f };
        },
        .linear_srgb => .{ .linear_srgb = .{ .r = c.data.linear_srgb.r, .g = c.data.linear_srgb.g, .b = c.data.linear_srgb.b } },
        .display_p3 => .{ .display_p3 = .{ .r = c.data.display_p3.r, .g = c.data.display_p3.g, .b = c.data.display_p3.b } },
        .linear_display_p3 => .{ .linear_display_p3 = .{ .r = c.data.linear_display_p3.r, .g = c.data.linear_display_p3.g, .b = c.data.linear_display_p3.b } },
        .rec2020 => .{ .rec2020 = .{ .r = c.data.rec2020.r, .g = c.data.rec2020.g, .b = c.data.rec2020.b } },
        .rec2020_scene => .{ .rec2020scene = .{ .r = c.data.rec2020_scene.r, .g = c.data.rec2020_scene.g, .b = c.data.rec2020_scene.b } },
        .linear_rec2020 => .{ .linear_rec2020 = .{ .r = c.data.linear_rec2020.r, .g = c.data.linear_rec2020.g, .b = c.data.linear_rec2020.b } },
        .hsl => .{ .hsl = .{ .h = hueFromC(c.data.hsl.h), .s = c.data.hsl.s, .l = c.data.hsl.l } },
        .hsv => .{ .hsv = .{ .h = hueFromC(c.data.hsv.h), .s = c.data.hsv.s, .v = c.data.hsv.v } },
        .hwb => .{ .hwb = .{ .h = hueFromC(c.data.hwb.h), .w = c.data.hwb.w, .b = c.data.hwb.b } },
        .hsi => .{ .hsi = .{ .h = hueFromC(c.data.hsi.h), .s = c.data.hsi.s, .i = c.data.hsi.i } },
        .cmyk => .{ .cmyk = .{ .c = c.data.cmyk.c, .m = c.data.cmyk.m, .y = c.data.cmyk.y, .k = c.data.cmyk.k } },
        .xyz => .{ .cie_xyz = .{ .x = c.data.xyz.x, .y = c.data.xyz.y, .z = c.data.xyz.z } },
        .yxy => .{ .cie_yxy = .{ .luma = c.data.yxy.luma, .x = c.data.yxy.x, .y = c.data.yxy.y } },
        .lab => .{ .cie_lab = .{ .l = c.data.lab.l, .a = c.data.lab.a, .b = c.data.lab.b } },
        .lch => .{ .cie_lch = .{ .l = c.data.lch.l, .c = c.data.lch.c, .h = hueFromC(c.data.lch.h) } },
        .oklab => .{ .oklab = .{ .l = c.data.oklab.l, .a = c.data.oklab.a, .b = c.data.oklab.b } },
        .oklch => .{ .oklch = .{ .l = c.data.oklch.l, .c = c.data.oklch.c, .h = hueFromC(c.data.oklch.h) } },
    };
}

// Pack: internal Color -> C Color

fn pack(ic: color.Color, alpha: f32, dst: Space) Color {
    // Handle srgb_u8 specially
    if (dst == .srgb_u8) {
        const srgb = ic.srgb;
        return .{ .space = .srgb_u8, .alpha = alpha, .data = .{ .srgb_u8 = .{
            .r = @intFromFloat(@round(srgb.r * 255)),
            .g = @intFromFloat(@round(srgb.g * 255)),
            .b = @intFromFloat(@round(srgb.b * 255)),
        } } };
    }
    return .{ .space = dst, .alpha = alpha, .data = switch (ic) {
        .srgb => |v| .{ .srgb = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_srgb => |v| .{ .linear_srgb = .{ .r = v.r, .g = v.g, .b = v.b } },
        .display_p3 => |v| .{ .display_p3 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_display_p3 => |v| .{ .linear_display_p3 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .rec2020 => |v| .{ .rec2020 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .rec2020scene => |v| .{ .rec2020_scene = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_rec2020 => |v| .{ .linear_rec2020 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .hsl => |v| .{ .hsl = .{ .h = hueToC(v.h), .s = v.s, .l = v.l } },
        .hsv => |v| .{ .hsv = .{ .h = hueToC(v.h), .s = v.s, .v = v.v } },
        .hwb => |v| .{ .hwb = .{ .h = hueToC(v.h), .w = v.w, .b = v.b } },
        .hsi => |v| .{ .hsi = .{ .h = hueToC(v.h), .s = v.s, .i = v.i } },
        .cmyk => |v| .{ .cmyk = .{ .c = v.c, .m = v.m, .y = v.y, .k = v.k } },
        .cie_xyz => |v| .{ .xyz = .{ .x = v.x, .y = v.y, .z = v.z } },
        .cie_yxy => |v| .{ .yxy = .{ .luma = v.luma, .x = v.x, .y = v.y } },
        .cie_lab => |v| .{ .lab = .{ .l = v.l, .a = v.a, .b = v.b } },
        .cie_lch => |v| .{ .lch = .{ .l = v.l, .c = v.c, .h = hueToC(v.h) } },
        .oklab => |v| .{ .oklab = .{ .l = v.l, .a = v.a, .b = v.b } },
        .oklch => |v| .{ .oklch = .{ .l = v.l, .c = v.c, .h = hueToC(v.h) } },
    } };
}

// Exported C API

export fn chroma_convert(src: Color, dst_space: Space) Color {
    const internal = unpack(src);
    const target = toInternalSpace(dst_space);
    const result = color.convert(internal, target);
    return pack(result, src.alpha, dst_space);
}

export fn chroma_is_in_gamut(src: Color, gamut_space: Space) bool {
    const xyz = color.toCieXyz(unpack(src));
    return switch (gamut_space) {
        .srgb, .srgb_u8 => lib.Srgb(f32).fromCieXyz(xyz).isInGamut(),
        .linear_srgb => lib.LinearSrgb(f32).fromCieXyz(xyz).isInGamut(),
        .display_p3 => lib.DisplayP3(f32).fromCieXyz(xyz).isInGamut(),
        .linear_display_p3 => lib.LinearDisplayP3(f32).fromCieXyz(xyz).isInGamut(),
        .rec2020 => lib.Rec2020(f32).fromCieXyz(xyz).isInGamut(),
        .rec2020_scene => lib.Rec2020Scene(f32).fromCieXyz(xyz).isInGamut(),
        .linear_rec2020 => lib.LinearRec2020(f32).fromCieXyz(xyz).isInGamut(),
        else => true,
    };
}

export fn chroma_gamut_map(src: Color, target_space: Space) Color {
    const xyz = color.toCieXyz(unpack(src));
    const internal_space = toInternalSpace(target_space);
    // Non-RGB targets: just convert, no gamut mapping needed
    return switch (target_space) {
        .srgb => pack(.{ .srgb = lib.gamut.gamutMap(xyz, lib.Srgb(f32)) }, src.alpha, target_space),
        .srgb_u8 => blk: {
            const mapped = lib.gamut.gamutMap(xyz, lib.Srgb(f32));
            break :blk pack(.{ .srgb = mapped }, src.alpha, .srgb_u8);
        },
        .linear_srgb => pack(.{ .linear_srgb = lib.gamut.gamutMap(xyz, lib.LinearSrgb(f32)) }, src.alpha, target_space),
        .display_p3 => pack(.{ .display_p3 = lib.gamut.gamutMap(xyz, lib.DisplayP3(f32)) }, src.alpha, target_space),
        .linear_display_p3 => pack(.{ .linear_display_p3 = lib.gamut.gamutMap(xyz, lib.LinearDisplayP3(f32)) }, src.alpha, target_space),
        .rec2020 => pack(.{ .rec2020 = lib.gamut.gamutMap(xyz, lib.Rec2020(f32)) }, src.alpha, target_space),
        .rec2020_scene => pack(.{ .rec2020scene = lib.gamut.gamutMap(xyz, lib.Rec2020Scene(f32)) }, src.alpha, target_space),
        .linear_rec2020 => pack(.{ .linear_rec2020 = lib.gamut.gamutMap(xyz, lib.LinearRec2020(f32)) }, src.alpha, target_space),
        else => pack(color.fromCieXyz(xyz, internal_space), src.alpha, target_space),
    };
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
