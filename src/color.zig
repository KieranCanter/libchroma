const std = @import("std");

// Sub-namespace re-exports

pub const rgb = @import("color/rgb.zig");
pub const hsm = @import("color/hsm.zig");
pub const xyz = @import("color/xyz.zig");
pub const lab = @import("color/lab.zig");
pub const lch = @import("color/lch.zig");
pub const cmyk = @import("color/cmyk.zig");

// Type shortcuts

pub const Cmyk = cmyk.Cmyk;
pub const Hsi = hsm.Hsi;
pub const Hsl = hsm.Hsl;
pub const Hsv = hsm.Hsv;
pub const Hwb = hsm.Hwb;
pub const CieLab = lab.CieLab;
pub const CieLch = lch.CieLch;
pub const Oklab = lab.Oklab;
pub const Oklch = lch.Oklch;
pub const CieXyz = xyz.CieXyz;
pub const CieYxy = xyz.CieYxy;
pub const RgbError = rgb.RgbError;

pub const Srgb = rgb.Srgb;
pub const LinearSrgb = rgb.LinearSrgb;
pub const DisplayP3 = rgb.DisplayP3;
pub const LinearDisplayP3 = rgb.LinearDisplayP3;
pub const Rec2020 = rgb.Rec2020;
pub const Rec2020Scene = rgb.Rec2020Scene;
pub const LinearRec2020 = rgb.LinearRec2020;

// Color union (runtime)

/// Single source of truth for all color space constructors.
/// Space, Color, and AlphaColor are all generated from this list.
const color_spaces = .{
    CieXyz,
    CieYxy,
    Srgb,
    LinearSrgb,
    DisplayP3,
    LinearDisplayP3,
    Rec2020,
    Rec2020Scene,
    LinearRec2020,
    Hsl,
    Hsv,
    Hsi,
    Hwb,
    Cmyk,
    CieLab,
    CieLch,
    Oklab,
    Oklch,
};

const n_spaces = color_spaces.len;

const field_names: [n_spaces][]const u8 = blk: {
    // Raise the comptime branch limit (default 1000) since generating snake_case names for all color spaces requires
    // many evaluations.
    @setEvalBranchQuota(10000);
    var result: [n_spaces][]const u8 = undefined;
    for (0..n_spaces) |i| result[i] = std.fmt.comptimePrint("{s}", .{toSnakeCase(typeName(color_spaces[i]))});
    break :blk result;
};

const field_types: [n_spaces]type = blk: {
    var result: [n_spaces]type = undefined;
    for (0..n_spaces) |i| result[i] = color_spaces[i](f32);
    break :blk result;
};

const tag_values: [n_spaces]u8 = blk: {
    var result: [n_spaces]u8 = undefined;
    for (0..n_spaces) |i| result[i] = i;
    break :blk result;
};

const no_attrs: [n_spaces]std.builtin.Type.UnionField.Attributes = @splat(.{});

pub const Space = @Enum(u8, .exhaustive, &field_names, &tag_values);
pub const Color = @Union(.auto, Space, &field_names, &field_types, &no_attrs);

pub const AlphaColor = struct {
    color: Color,
    a: f32 = 1.0,
};

// Color functions — accept Color or AlphaColor

pub fn convert(src: anytype, dest: Space) @TypeOf(src) {
    return switch (@TypeOf(src)) {
        Color => fromCieXyz(toCieXyz(src), dest),
        AlphaColor => .{ .color = fromCieXyz(toCieXyz(src.color), dest), .a = src.a },
        else => @compileError("expected Color or AlphaColor"),
    };
}

pub fn toCieXyz(src: anytype) CieXyz(f32) {
    const inner = switch (@TypeOf(src)) {
        Color => src,
        AlphaColor => src.color,
        else => @compileError("expected Color or AlphaColor"),
    };
    return switch (inner) {
        inline else => |c| c.toCieXyz(),
    };
}

pub fn fromCieXyz(src: CieXyz(f32), dest: Space) Color {
    const fields = @typeInfo(Color).@"union".fields;
    return switch (dest) {
        inline else => |tag| @unionInit(Color, @tagName(tag), fields[@intFromEnum(tag)].type.fromCieXyz(src)),
    };
}

pub const InitError = error{InvalidValueCount};

pub fn initFromSlice(space: Space, vals: []const f32) InitError!Color {
    const fields = @typeInfo(Color).@"union".fields;
    return switch (space) {
        inline else => |tag| {
            const T = fields[@intFromEnum(tag)].type;
            const type_fields = @typeInfo(T).@"struct".fields;
            if (vals.len != type_fields.len) return error.InvalidValueCount;
            var result: T = undefined;
            inline for (type_fields, 0..) |f, i| {
                @field(result, f.name) = vals[i];
            }
            return @unionInit(Color, @tagName(tag), result);
        },
    };
}

pub fn withAlpha(c: Color, a: f32) AlphaColor {
    return .{ .color = c, .a = a };
}

pub fn format(src: anytype, writer: *std.Io.Writer) std.Io.Writer.Error!void {
    switch (@TypeOf(src)) {
        Color => switch (src) {
            inline else => |c| try c.format(writer),
        },
        AlphaColor => {
            switch (src.color) {
                inline else => |c| try c.format(writer),
            }
            try writer.print(", {d}", .{src.a});
        },
        else => @compileError("expected Color or AlphaColor"),
    }
}

// Comptime helpers

fn typeName(comptime constructor: anytype) []const u8 {
    const full = @typeName(constructor(f32));
    const last_dot = std.mem.lastIndexOfScalar(u8, full, '.') orelse 0;
    const start = if (last_dot > 0) last_dot + 1 else 0;
    const paren = std.mem.indexOfScalar(u8, full[start..], '(') orelse full[start..].len;
    return full[start .. start + paren];
}

fn toSnakeCase(comptime input: []const u8) [:0]const u8 {
    comptime {
        var buf: [input.len * 2 + 1]u8 = undefined;
        var len: usize = 0;
        for (input, 0..) |c, i| {
            if (std.ascii.isUpper(c)) {
                if (i > 0 and std.ascii.isLower(input[i - 1])) {
                    buf[len] = '_';
                    len += 1;
                }
                if (i > 0 and std.ascii.isUpper(input[i - 1]) and
                    i + 1 < input.len and std.ascii.isLower(input[i + 1]))
                {
                    buf[len] = '_';
                    len += 1;
                }
                buf[len] = std.ascii.toLower(c);
            } else {
                buf[len] = c;
            }
            len += 1;
        }
        buf[len] = 0;
        const final = buf[0..len :0];
        return final;
    }
}

// Tests

test "Color.convert runtime" {
    const srgb_val = Srgb(f32).init(0.7843, 0.3922, 0.1961);
    const c = Color{ .srgb = srgb_val };
    const result = convert(c, .oklch);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6138), result.oklch.l, 0.002);
    try std.testing.expectApproxEqAbs(@as(f32, 0.1423), result.oklch.c, 0.002);
}

test "AlphaColor.convert preserves alpha" {
    const srgb_val = Srgb(f32).init(0.7843, 0.3922, 0.1961);
    const ac = withAlpha(.{ .srgb = srgb_val }, 0.5);
    const result = convert(ac, .oklch);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), result.a, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.6138), result.color.oklch.l, 0.002);
}

test "Color has all color spaces" {
    try std.testing.expectEqual(n_spaces, @typeInfo(Color).@"union".fields.len);
    try std.testing.expectEqual(n_spaces, @typeInfo(Space).@"enum".fields.len);
}
