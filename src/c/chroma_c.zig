// C ABI bridge. Maps between extern C types and internal Zig color types.

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

// C-side space enum, generated from color.Space
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

/// C-compatible color space enum matching the internal `Space`.
pub const CSpace = @Enum(c_int, .exhaustive, &cspace_names, &cspace_values);

fn toInternalSpace(s: CSpace) color.Space {
    return @enumFromInt(@intFromEnum(s));
}

// C-side color data structs
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

const CColorData = @Union(.@"extern", null, &cspace_names, &ccolordata_types, &no_attrs);

/// C-compatible color tagged union matching internal `Color`.
pub const CColor = extern struct {
    space: CSpace,
    data: CColorData,
};

/// C-compatible color with alpha channel matching internal `AlphaColor`.
pub const CAlphaColor = extern struct {
    color: CColor,
    alpha: f32,
};

// C Color -> internal Color
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

// Internal Color -> C Color
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

// Exported functions

/// Convert a color to a different color space.
export fn chroma_convert(src: CColor, dst_space: CSpace) CColor {
    const internal = unpack(src);
    const target = toInternalSpace(dst_space);
    const result = color.convert(internal, target);
    return pack(result, dst_space);
}

/// Check whether a color is within the gamut of the given space.
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

/// Map a color into the gamut of target_space via OKLCH chroma reduction.
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

/// Create a `CColor` from a space and a pointer to float channel values.
/// The number of floats passed in `vals` should equal the number of fields in `space`.
export fn chroma_init(space: CSpace, vals: [*]const f32) CColor {
    var c = CColor{ .space = space, .data = undefined };
    const dst: [*]f32 = @ptrCast(&c.data);
    const n = fieldCount(space);
    @memcpy(dst[0..n], vals[0..n]);
    return c;
}

/// Copy channel values out of a `CColor` into a float buffer; returns channel count.
/// The size of `vals` should equal the number of fields in `clr`.
export fn chroma_unpack(clr: CColor, vals: [*]f32) c_int {
    const src: [*]const f32 = @ptrCast(&clr.data);
    const n = fieldCount(clr.space);
    @memcpy(vals[0..n], src[0..n]);
    return @intCast(n);
}

/// Create a `CAlphaColor` from a space, channel values, and alpha.
/// The number of floats passed in `vals` should equal the number of fields in `space`.
export fn chroma_init_alpha(space: CSpace, vals: [*]const f32, alpha: f32) CAlphaColor {
    return .{ .color = chroma_init(space, vals), .alpha = alpha };
}

/// Unpack a CAlphaColor into channel values and alpha; returns channel count.
/// The size of `vals` should equal the number of fields in `aclr.color`.
export fn chroma_unpack_alpha(aclr: CAlphaColor, vals: [*]f32, alpha: *f32) c_int {
    alpha.* = aclr.alpha;
    return chroma_unpack(aclr.color, vals);
}

/// Create an sRGB `CColor` from 8-bit r/g/b values.
export fn chroma_init_srgb8(r: u8, g: u8, b: u8) CColor {
    return .{ .space = .srgb, .data = .{ .srgb = .{
        .r = @as(f32, @floatFromInt(r)) / 255.0,
        .g = @as(f32, @floatFromInt(g)) / 255.0,
        .b = @as(f32, @floatFromInt(b)) / 255.0,
    } } };
}

/// Convert any `CColor` to sRGB and write out 8-bit r/g/b values.
export fn chroma_unpack_srgb8(clr: CColor, r: *u8, g: *u8, b: *u8) void {
    const srgb = color.convert(unpack(clr), .srgb).srgb;
    r.* = @intFromFloat(@round(srgb.r * 255));
    g.* = @intFromFloat(@round(srgb.g * 255));
    b.* = @intFromFloat(@round(srgb.b * 255));
}

/// Create an sRGB `CColor` from a 24-bit hex value (0xRRGGBB).
export fn chroma_init_hex(hex: u32) CColor {
    const srgb = lib.Srgb(f32).initFromHex(@truncate(hex));
    return .{ .space = .srgb, .data = .{ .srgb = .{ .r = srgb.r, .g = srgb.g, .b = srgb.b } } };
}

/// Convert any `CColor` to sRGB and return a 24-bit hex value.
/// The most significant 8 bits are guaranteed to be 0.
export fn chroma_unpack_hex(clr: CColor) u32 {
    const srgb = color.convert(unpack(clr), .srgb).srgb;
    return lib.Srgb(f32).init(srgb.r, srgb.g, srgb.b).toHex();
}

/// Create an sRGBA color from 8-bit r/g/b/a values.
export fn chroma_init_srgba8(r: u8, g: u8, b: u8, a: u8) CAlphaColor {
    return .{ .color = chroma_init_srgb8(r, g, b), .alpha = @as(f32, @floatFromInt(a)) / 255.0 };
}

/// Convert any `CAlphaColor` to sRGBA and write out 8-bit r/g/b/a values.
export fn chroma_unpack_srgba8(aclr: CAlphaColor, r: *u8, g: *u8, b: *u8, a: *u8) void {
    chroma_unpack_srgb8(aclr.color, r, g, b);
    a.* = @intFromFloat(@round(aclr.alpha * 255));
}

/// Create an sRGB alpha color from a 32-bit hex alpha value (0xRRGGBBAA).
export fn chroma_init_hexa(rgba: u32) CAlphaColor {
    return .{
        .color = chroma_init_hex(rgba >> 8),
        .alpha = @as(f32, @floatFromInt(rgba & 0xFF)) / 255.0,
    };
}

/// Convert any `CAlphaColor` to sRGB and return a 32-bit 0xRRGGBBAA value.
export fn chroma_unpack_hexa(aclr: CAlphaColor) u32 {
    const rgb = chroma_unpack_hex(aclr.color);
    const a: u8 = @intFromFloat(@round(aclr.alpha * 255));
    return (rgb << 8) | a;
}

// Tests

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

test "chroma_init_srgba8 and chroma_unpack_srgba8" {
    const c = chroma_init_srgba8(200, 100, 50, 128);
    try std.testing.expectApproxEqAbs(@as(f32, 0.502), c.alpha, 0.005);
    var r: u8 = undefined;
    var g: u8 = undefined;
    var b: u8 = undefined;
    var a: u8 = undefined;
    chroma_unpack_srgba8(c, &r, &g, &b, &a);
    try std.testing.expectEqual(@as(u8, 200), r);
    try std.testing.expectEqual(@as(u8, 100), g);
    try std.testing.expectEqual(@as(u8, 50), b);
    try std.testing.expectEqual(@as(u8, 128), a);
}

test "chroma_init_hexa and chroma_unpack_hexa" {
    const c = chroma_init_hexa(0xC8643280);
    try std.testing.expectApproxEqAbs(@as(f32, 0.784), c.color.data.srgb.r, 0.002);
    try std.testing.expectApproxEqAbs(@as(f32, 0.502), c.alpha, 0.005);
    try std.testing.expectEqual(@as(u32, 0xC8643280), chroma_unpack_hexa(c));
}

test "chroma_is_in_gamut srgb color in srgb" {
    const c = chroma_init(.srgb, &[_]f32{ 0.5, 0.3, 0.1 });
    try std.testing.expect(chroma_is_in_gamut(c, .srgb));
}

test "chroma_is_in_gamut out-of-gamut color" {
    const c = chroma_init(.srgb, &[_]f32{ 1.5, 0.3, 0.1 });
    try std.testing.expect(!chroma_is_in_gamut(c, .srgb));
}

test "chroma_gamut_map clamps to gamut" {
    const c = chroma_init(.srgb, &[_]f32{ 1.5, 0.3, -0.2 });
    const mapped = chroma_gamut_map(c, .srgb);
    var vals: [4]f32 = undefined;
    _ = chroma_unpack(mapped, &vals);
    try std.testing.expect(vals[0] >= 0.0 and vals[0] <= 1.0);
    try std.testing.expect(vals[2] >= 0.0 and vals[2] <= 1.0);
}

test "NaN hue round-trip through C ABI" {
    // Grey has no hue, should come back as NaN
    const grey = chroma_init(.srgb, &[_]f32{ 0.5, 0.5, 0.5 });
    const hsl = chroma_convert(grey, .hsl);
    try std.testing.expect(std.math.isNan(hsl.data.hsl.h));
    // Convert back, should still work
    const back = chroma_convert(hsl, .srgb);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), back.data.srgb.r, 0.002);
}

test "C ABI header enum matches Zig CSpace" {
    const c = @import("chroma_h");
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
