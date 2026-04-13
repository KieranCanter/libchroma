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

// C ABI types — Space generated from color.Space

/// chroma_space_t
/// Models color.Space in color.zig.
const internal_fields = @typeInfo(color.Space).@"enum".fields;
const n_spaces = internal_fields.len;

const cspace_names: [n_spaces][]const u8 = blk: {
    var result: [n_spaces][]const u8 = undefined;
    for (0..n_spaces) |i| result[i] = internal_fields[i].name;
    break :blk result;
};
const cspace_values: [n_spaces]c_int = blk: {
    var result: [n_spaces]c_int = undefined;
    for (0..n_spaces) |i| result[i] = @intCast(internal_fields[i].value);
    break :blk result;
};

pub const CSpace = @Enum(c_int, .exhaustive, &cspace_names, &cspace_values);

fn toInternalSpace(s: CSpace) color.Space {
    return @enumFromInt(@intFromEnum(s));
}

/// chroma_<color-type>_t types
/// Models color_spaces in color.zig.
const CRgb = extern struct { r: f32, g: f32, b: f32 };
const CHsl = extern struct { h: f32, s: f32, l: f32 };
const CHsv = extern struct { h: f32, s: f32, v: f32 };
const CHwb = extern struct { h: f32, w: f32, b: f32 };
const CHsi = extern struct { h: f32, s: f32, i: f32 };
const CCmyk = extern struct { c: f32, m: f32, y: f32, k: f32 };
const CXyz = extern struct { x: f32, y: f32, z: f32 };
const CYxy = extern struct { luma: f32, x: f32, y: f32 };
const CLab = extern struct { l: f32, a: f32, b: f32 };
const CLch = extern struct { l: f32, c: f32, h: f32 };

/// Maps each color space to its C-compatible struct type.
/// Models color.Color
fn spaceToCColorData(comptime space: color.Space) type {
    return switch (space) {
        .srgb, .linear_srgb, .display_p3, .linear_display_p3, .rec2020, .rec2020scene, .linear_rec2020 => CRgb,
        .hsl => CHsl,
        .hsv => CHsv,
        .hwb => CHwb,
        .hsi => CHsi,
        .cmyk => CCmyk,
        .cie_xyz => CXyz,
        .cie_yxy => CYxy,
        .cie_lab, .oklab => CLab,
        .cie_lch, .oklch => CLch,
    };
}

const ccolordata_types: [n_spaces]type = blk: {
    var result: [n_spaces]type = undefined;
    for (0..n_spaces) |i| {
        const space: color.Space = @enumFromInt(internal_fields[i].value);
        result[i] = spaceToCColorData(space);
    }
    break :blk result;
};

const no_attrs: [n_spaces]std.builtin.Type.UnionField.Attributes = @splat(.{});

/// chroma_color_data_t
const CColorData = @Union(.@"extern", null, &cspace_names, &ccolordata_types, &no_attrs);

/// chroma_color_t
pub const CColor = extern struct {
    space: CSpace,
    data: CColorData,
};

/// chroma_alpha_color_t
pub const CAlphaColor = extern struct {
    color: CColor,
    alpha: f32,
};

// Unpack: C Color -> internal Color

fn unpack(c: CColor) color.Color {
    return switch (c.space) {
        .srgb => .{ .srgb = .{ .r = c.data.srgb.r, .g = c.data.srgb.g, .b = c.data.srgb.b } },
        .linear_srgb => .{ .linear_srgb = .{ .r = c.data.linear_srgb.r, .g = c.data.linear_srgb.g, .b = c.data.linear_srgb.b } },
        .display_p3 => .{ .display_p3 = .{ .r = c.data.display_p3.r, .g = c.data.display_p3.g, .b = c.data.display_p3.b } },
        .linear_display_p3 => .{ .linear_display_p3 = .{ .r = c.data.linear_display_p3.r, .g = c.data.linear_display_p3.g, .b = c.data.linear_display_p3.b } },
        .rec2020 => .{ .rec2020 = .{ .r = c.data.rec2020.r, .g = c.data.rec2020.g, .b = c.data.rec2020.b } },
        .rec2020scene => .{ .rec2020scene = .{ .r = c.data.rec2020scene.r, .g = c.data.rec2020scene.g, .b = c.data.rec2020scene.b } },
        .linear_rec2020 => .{ .linear_rec2020 = .{ .r = c.data.linear_rec2020.r, .g = c.data.linear_rec2020.g, .b = c.data.linear_rec2020.b } },
        .hsl => .{ .hsl = .{ .h = hueFromC(c.data.hsl.h), .s = c.data.hsl.s, .l = c.data.hsl.l } },
        .hsv => .{ .hsv = .{ .h = hueFromC(c.data.hsv.h), .s = c.data.hsv.s, .v = c.data.hsv.v } },
        .hwb => .{ .hwb = .{ .h = hueFromC(c.data.hwb.h), .w = c.data.hwb.w, .b = c.data.hwb.b } },
        .hsi => .{ .hsi = .{ .h = hueFromC(c.data.hsi.h), .s = c.data.hsi.s, .i = c.data.hsi.i } },
        .cmyk => .{ .cmyk = .{ .c = c.data.cmyk.c, .m = c.data.cmyk.m, .y = c.data.cmyk.y, .k = c.data.cmyk.k } },
        .cie_xyz => .{ .cie_xyz = .{ .x = c.data.cie_xyz.x, .y = c.data.cie_xyz.y, .z = c.data.cie_xyz.z } },
        .cie_yxy => .{ .cie_yxy = .{ .luma = c.data.cie_yxy.luma, .x = c.data.cie_yxy.x, .y = c.data.cie_yxy.y } },
        .cie_lab => .{ .cie_lab = .{ .l = c.data.cie_lab.l, .a = c.data.cie_lab.a, .b = c.data.cie_lab.b } },
        .cie_lch => .{ .cie_lch = .{ .l = c.data.cie_lch.l, .c = c.data.cie_lch.c, .h = hueFromC(c.data.cie_lch.h) } },
        .oklab => .{ .oklab = .{ .l = c.data.oklab.l, .a = c.data.oklab.a, .b = c.data.oklab.b } },
        .oklch => .{ .oklch = .{ .l = c.data.oklch.l, .c = c.data.oklch.c, .h = hueFromC(c.data.oklch.h) } },
    };
}

// Pack: internal Color -> C Color

fn pack(ic: color.Color, dst: CSpace) CColor {
    return .{ .space = dst, .data = switch (ic) {
        .srgb => |v| .{ .srgb = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_srgb => |v| .{ .linear_srgb = .{ .r = v.r, .g = v.g, .b = v.b } },
        .display_p3 => |v| .{ .display_p3 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_display_p3 => |v| .{ .linear_display_p3 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .rec2020 => |v| .{ .rec2020 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .rec2020scene => |v| .{ .rec2020scene = .{ .r = v.r, .g = v.g, .b = v.b } },
        .linear_rec2020 => |v| .{ .linear_rec2020 = .{ .r = v.r, .g = v.g, .b = v.b } },
        .hsl => |v| .{ .hsl = .{ .h = hueToC(v.h), .s = v.s, .l = v.l } },
        .hsv => |v| .{ .hsv = .{ .h = hueToC(v.h), .s = v.s, .v = v.v } },
        .hwb => |v| .{ .hwb = .{ .h = hueToC(v.h), .w = v.w, .b = v.b } },
        .hsi => |v| .{ .hsi = .{ .h = hueToC(v.h), .s = v.s, .i = v.i } },
        .cmyk => |v| .{ .cmyk = .{ .c = v.c, .m = v.m, .y = v.y, .k = v.k } },
        .cie_xyz => |v| .{ .cie_xyz = .{ .x = v.x, .y = v.y, .z = v.z } },
        .cie_yxy => |v| .{ .cie_yxy = .{ .luma = v.luma, .x = v.x, .y = v.y } },
        .cie_lab => |v| .{ .cie_lab = .{ .l = v.l, .a = v.a, .b = v.b } },
        .cie_lch => |v| .{ .cie_lch = .{ .l = v.l, .c = v.c, .h = hueToC(v.h) } },
        .oklab => |v| .{ .oklab = .{ .l = v.l, .a = v.a, .b = v.b } },
        .oklch => |v| .{ .oklch = .{ .l = v.l, .c = v.c, .h = hueToC(v.h) } },
    } };
}

// Exported C API

export fn chroma_convert(src: CColor, dst_space: CSpace) CColor {
    const internal = unpack(src);
    const target = toInternalSpace(dst_space);
    const result = color.convert(internal, target);
    return pack(result, dst_space);
}

export fn chroma_is_in_gamut(src: CColor, gamut_space: CSpace) bool {
    const xyz = color.toCieXyz(unpack(src));
    return switch (gamut_space) {
        .srgb => lib.Srgb(f32).fromCieXyz(xyz).isInGamut(),
        .linear_srgb => lib.LinearSrgb(f32).fromCieXyz(xyz).isInGamut(),
        .display_p3 => lib.DisplayP3(f32).fromCieXyz(xyz).isInGamut(),
        .linear_display_p3 => lib.LinearDisplayP3(f32).fromCieXyz(xyz).isInGamut(),
        .rec2020 => lib.Rec2020(f32).fromCieXyz(xyz).isInGamut(),
        .rec2020scene => lib.Rec2020Scene(f32).fromCieXyz(xyz).isInGamut(),
        .linear_rec2020 => lib.LinearRec2020(f32).fromCieXyz(xyz).isInGamut(),
        else => true,
    };
}

export fn chroma_gamut_map(src: CColor, target_space: CSpace) CColor {
    const xyz = color.toCieXyz(unpack(src));
    const internal_space = toInternalSpace(target_space);
    return switch (target_space) {
        .srgb => pack(.{ .srgb = lib.gamut.gamutMap(xyz, lib.Srgb(f32)) }, target_space),
        .linear_srgb => pack(.{ .linear_srgb = lib.gamut.gamutMap(xyz, lib.LinearSrgb(f32)) }, target_space),
        .display_p3 => pack(.{ .display_p3 = lib.gamut.gamutMap(xyz, lib.DisplayP3(f32)) }, target_space),
        .linear_display_p3 => pack(.{ .linear_display_p3 = lib.gamut.gamutMap(xyz, lib.LinearDisplayP3(f32)) }, target_space),
        .rec2020 => pack(.{ .rec2020 = lib.gamut.gamutMap(xyz, lib.Rec2020(f32)) }, target_space),
        .rec2020scene => pack(.{ .rec2020scene = lib.gamut.gamutMap(xyz, lib.Rec2020Scene(f32)) }, target_space),
        .linear_rec2020 => pack(.{ .linear_rec2020 = lib.gamut.gamutMap(xyz, lib.LinearRec2020(f32)) }, target_space),
        else => pack(color.fromCieXyz(xyz, internal_space), target_space),
    };
}

fn fieldCount(space: CSpace) usize {
    return switch (toInternalSpace(space)) {
        .cmyk => 4,
        else => 3,
    };
}

export fn chroma_init(space: CSpace, vals: [*]const f32) CColor {
    var c = CColor{ .space = space, .data = undefined };
    const dst: [*]f32 = @ptrCast(&c.data);
    const n = fieldCount(space);
    @memcpy(dst[0..n], vals[0..n]);
    return c;
}

export fn chroma_unpack(c: CColor, vals: [*]f32) c_int {
    const src: [*]const f32 = @ptrCast(&c.data);
    const n = fieldCount(c.space);
    @memcpy(vals[0..n], src[0..n]);
    return @intCast(n);
}

export fn chroma_init_alpha(space: CSpace, vals: [*]const f32, alpha: f32) CAlphaColor {
    return .{ .color = chroma_init(space, vals), .alpha = alpha };
}

export fn chroma_unpack_alpha(c: CAlphaColor, vals: [*]f32, alpha: *f32) c_int {
    alpha.* = c.alpha;
    return chroma_unpack(c.color, vals);
}

export fn chroma_init_srgb8(r: u8, g: u8, b: u8) CColor {
    return .{ .space = .srgb, .data = .{ .srgb = .{
        .r = @as(f32, @floatFromInt(r)) / 255.0,
        .g = @as(f32, @floatFromInt(g)) / 255.0,
        .b = @as(f32, @floatFromInt(b)) / 255.0,
    } } };
}

export fn chroma_unpack_srgb8(c: CColor, r: *u8, g: *u8, b: *u8) void {
    const srgb = color.convert(unpack(c), .srgb).srgb;
    r.* = @intFromFloat(@round(srgb.r * 255));
    g.* = @intFromFloat(@round(srgb.g * 255));
    b.* = @intFromFloat(@round(srgb.b * 255));
}

export fn chroma_init_hex(hex: u32) CColor {
    const srgb = lib.Srgb(f32).initFromHex(@truncate(hex));
    return .{ .space = .srgb, .data = .{ .srgb = .{ .r = srgb.r, .g = srgb.g, .b = srgb.b } } };
}

export fn chroma_unpack_hex(c: CColor) u32 {
    const srgb = color.convert(unpack(c), .srgb).srgb;
    return lib.Srgb(f32).init(srgb.r, srgb.g, srgb.b).toHex();
}

// ============================================================================
// TESTS
// ============================================================================

test "chroma_convert srgb -> hsl" {
    const src = CColor{ .space = .srgb, .data = .{ .srgb = .{ .r = 0.8, .g = 0.4, .b = 0.2 } } };
    const dst = chroma_convert(src, .hsl);
    const tol: f32 = 0.002;
    try std.testing.expectEqual(.hsl, dst.space);
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), dst.data.hsl.h, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6), dst.data.hsl.s, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), dst.data.hsl.l, tol);
}

test "chroma_convert hsl -> oklab" {
    const src = CColor{ .space = .hsl, .data = .{ .hsl = .{ .h = 20.0, .s = 0.6, .l = 0.5 } } };
    const dst = chroma_convert(src, .oklab);
    try std.testing.expectEqual(.oklab, dst.space);
    try std.testing.expect(dst.data.oklab.l > 0.0 and dst.data.oklab.l < 1.0);
}

test "chroma_convert achromatic hue -> NaN" {
    const src = CColor{ .space = .srgb, .data = .{ .srgb = .{ .r = 0.5, .g = 0.5, .b = 0.5 } } };
    const dst = chroma_convert(src, .hsl);
    try std.testing.expect(std.math.isNan(dst.data.hsl.h));
}

test "chroma_convert round-trip srgb -> oklch -> srgb" {
    const original = CColor{ .space = .srgb, .data = .{ .srgb = .{ .r = 0.8, .g = 0.4, .b = 0.2 } } };
    const oklch = chroma_convert(original, .oklch);
    const result = chroma_convert(oklch, .srgb);
    const tol: f32 = 0.002;
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), result.data.srgb.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), result.data.srgb.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), result.data.srgb.b, tol);
}

test "chroma_init_srgb8 and chroma_unpack_srgb8" {
    const c = chroma_init_srgb8(200, 100, 50);
    var r: u8 = undefined;
    var g: u8 = undefined;
    var b: u8 = undefined;
    chroma_unpack_srgb8(c, &r, &g, &b);
    try std.testing.expectEqual(@as(u8, 200), r);
    try std.testing.expectEqual(@as(u8, 100), g);
    try std.testing.expectEqual(@as(u8, 50), b);
}

test "chroma_unpack_srgb8 with conversion" {
    const src = CColor{ .space = .hsl, .data = .{ .hsl = .{ .h = 20.0, .s = 0.6, .l = 0.5 } } };
    var r: u8 = undefined;
    var g: u8 = undefined;
    var b: u8 = undefined;
    chroma_unpack_srgb8(src, &r, &g, &b);
    try std.testing.expectEqual(@as(u8, 204), r);
    try std.testing.expectEqual(@as(u8, 102), g);
    try std.testing.expectEqual(@as(u8, 51), b);
}

test "chroma_init and chroma_unpack" {
    const vals = [_]f32{ 0.61, 0.14, 45.08 };
    const c = chroma_init(.oklch, &vals);
    try std.testing.expectEqual(.oklch, c.space);
    var out: [4]f32 = undefined;
    const n = chroma_unpack(c, &out);
    try std.testing.expectEqual(@as(c_int, 3), n);
    try std.testing.expectApproxEqAbs(@as(f32, 0.61), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.14), out[1], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 45.08), out[2], 0.001);
}

test "chroma_init_alpha and chroma_unpack_alpha" {
    const vals = [_]f32{ 0.78, 0.39, 0.2 };
    const ac = chroma_init_alpha(.srgb, &vals, 0.5);
    try std.testing.expectEqual(.srgb, ac.color.space);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), ac.alpha, 0.001);
    var out: [4]f32 = undefined;
    var alpha: f32 = undefined;
    const n = chroma_unpack_alpha(ac, &out, &alpha);
    try std.testing.expectEqual(@as(c_int, 3), n);
    try std.testing.expectApproxEqAbs(@as(f32, 0.78), out[0], 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), alpha, 0.001);
}

test "chroma_init cmyk (4 values)" {
    const vals = [_]f32{ 0.1, 0.2, 0.3, 0.4 };
    const c = chroma_init(.cmyk, &vals);
    var out: [4]f32 = undefined;
    const n = chroma_unpack(c, &out);
    try std.testing.expectEqual(@as(c_int, 4), n);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), out[3], 0.001);
}

test "chroma_init_hex and chroma_unpack_hex" {
    const c = chroma_init_hex(0xC86432);
    try std.testing.expectEqual(.srgb, c.space);
    try std.testing.expectApproxEqAbs(@as(f32, 0.784), c.data.srgb.r, 0.002);
    try std.testing.expectEqual(@as(u32, 0xC86432), chroma_unpack_hex(c));
}

test "chroma_unpack_hex with conversion" {
    const c = chroma_init_hex(0xC86432);
    const oklch = chroma_convert(c, .oklch);
    const hex = chroma_unpack_hex(oklch);
    try std.testing.expectEqual(@as(u32, 0xC86432), hex);
}

test "C ABI header enum matches Zig CSpace" {
    const c = @cImport(@cInclude("chroma.h"));
    try std.testing.expectEqual(c.CHROMA_XYZ, @intFromEnum(CSpace.cie_xyz));
    try std.testing.expectEqual(c.CHROMA_YXY, @intFromEnum(CSpace.cie_yxy));
    try std.testing.expectEqual(c.CHROMA_SRGB, @intFromEnum(CSpace.srgb));
    try std.testing.expectEqual(c.CHROMA_LINEAR_SRGB, @intFromEnum(CSpace.linear_srgb));
    try std.testing.expectEqual(c.CHROMA_DISPLAY_P3, @intFromEnum(CSpace.display_p3));
    try std.testing.expectEqual(c.CHROMA_LINEAR_DISPLAY_P3, @intFromEnum(CSpace.linear_display_p3));
    try std.testing.expectEqual(c.CHROMA_REC2020, @intFromEnum(CSpace.rec2020));
    try std.testing.expectEqual(c.CHROMA_REC2020_SCENE, @intFromEnum(CSpace.rec2020scene));
    try std.testing.expectEqual(c.CHROMA_LINEAR_REC2020, @intFromEnum(CSpace.linear_rec2020));
    try std.testing.expectEqual(c.CHROMA_HSL, @intFromEnum(CSpace.hsl));
    try std.testing.expectEqual(c.CHROMA_HSV, @intFromEnum(CSpace.hsv));
    try std.testing.expectEqual(c.CHROMA_HSI, @intFromEnum(CSpace.hsi));
    try std.testing.expectEqual(c.CHROMA_HWB, @intFromEnum(CSpace.hwb));
    try std.testing.expectEqual(c.CHROMA_CMYK, @intFromEnum(CSpace.cmyk));
    try std.testing.expectEqual(c.CHROMA_LAB, @intFromEnum(CSpace.cie_lab));
    try std.testing.expectEqual(c.CHROMA_LCH, @intFromEnum(CSpace.cie_lch));
    try std.testing.expectEqual(c.CHROMA_OKLAB, @intFromEnum(CSpace.oklab));
    try std.testing.expectEqual(c.CHROMA_OKLCH, @intFromEnum(CSpace.oklch));
}
