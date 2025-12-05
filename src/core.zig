const std = @import("std");
const colors = @import("colors.zig");

/// Enum representing one of the supported color
/// Tagged union representing on of the supported color space types as a value.
/// Alpha component wrapper to provide transparency.
pub const color = blk: {
    const decls = @typeInfo(colors).@"struct".decls;
    var names: [decls.len][]const u8 = undefined;
    var types: [decls.len]type = undefined;

    for (decls, &names, &types) |decl, *name, *T| {
        var buf: [decl.name.len]u8 = undefined;
        const n = std.ascii.upperString(&buf, decl.name);
        name.* = n;
        T.* = @field(colors, decl.name);
    }
    const IntTag = std.math.IntFittingRange(0, decls.len -| 1);

    const ColorSpace = @Enum(u8, .exhaustive, &names, &std.simd.iota(IntTag, names.len));
    const Color = @Union(.auto, ColorSpace, &names, &types, &@splat(.{}));
    const AlphaColor = struct {
        value: Color,
        alpha: f32,
    };

    break :blk .{
        .ColorSpace = ColorSpace,
        .Color = Color,
        .AlphaColor = AlphaColor,
    };
};


test "aggregate types properly constructed" {
    inline for (@typeInfo(color.ColorSpace).@"enum".fields) |f| {
        std.debug.print("ColorSpace: {s}\n", .{f.name});
    }
    inline for (@typeInfo(color.Color).@"union".fields) |f| {
        std.debug.print("Color: {s}: {any}\n", .{ f.name, f.type });
    }
    inline for (@typeInfo(color.AlphaColor).@"struct".fields) |f| {
        std.debug.print("AlphaColor: {s}: {any}\n", .{ f.name, f.type });
    }
}
