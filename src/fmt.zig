const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;
const colorSpaceName = @import("validation.zig").colorSpaceName;
const color_mod = @import("color.zig");
const Alpha = @import("color/alpha.zig").Alpha;

pub const FormatStyle = enum {
    default,
    raw,
    pretty,
};

/// Comptime formatter for concrete comptime Color types.
pub fn TypeFormat(comptime T: type) type {
    assertColorInterface(T);

    return struct {
        const Self = @This();

        color: T,
        style: FormatStyle,

        pub fn init(color: T, style: FormatStyle) Self {
            return .{ .color = color, .style = style };
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            switch (self.style) {
                .raw => {
                    const typeName = colorSpaceName(Self);
                    try writer.print("{s}{any}", .{ typeName, self.color });
                },
                .default => {
                    try self.color.format(writer);
                },
                .pretty => {
                    // Call type's formatPretty() if it has one
                    if (@hasDecl(T, "formatPretty"))
                        return @call(.auto, @field(T, "formatPretty"), .{ self.color, writer });

                    // Otherwise fall back to wrapping
                    const typeName = colorSpaceName(Self);
                    try writer.print("{s}({f})", .{ typeName, self.color });
                },
            }
        }
    };
}

/// Runtime formatter for the Color/AlphaColor tagged union. Works with print's {f} specifier.
pub const ColorFormat = struct {
    const Self = @This();

    color: color_mod.Color,
    alpha: ?f32 = null,
    style: FormatStyle = .default,

    pub fn init(src: anytype, style: FormatStyle) Self {
        return switch (@TypeOf(src)) {
            color_mod.Color => .{ .color = src, .style = style },
            color_mod.AlphaColor => .{ .color = src.color, .alpha = src.alpha, .style = style },
            else => @compileError("expected Color or AlphaColor"),
        };
    }

    pub fn format(self: Self, w: *std.Io.Writer) std.Io.Writer.Error!void {
        if (self.alpha) |a| {
            switch (self.style) {
                .default => {
                    switch (self.color) {
                        inline else => |c| try c.format(w),
                    }
                    try w.print(", {d}", .{a});
                },
                .raw => {
                    switch (self.color) {
                        inline else => |c| try w.print("{any}, a={d}", .{ c, a }),
                    }
                },
                .pretty => {
                    const name = @tagName(self.color);
                    try w.print("{s}(", .{name});
                    switch (self.color) {
                        inline else => |c| try c.format(w),
                    }
                    try w.print(", a={d})", .{a});
                },
            }
        } else {
            switch (self.color) {
                inline else => |c| try c.formatter(self.style).format(w),
            }
        }
    }
};

/// Return a `ColorFormat` with default style.
pub fn formatter(clr: anytype, style: FormatStyle) ColorFormat {
    return ColorFormat.init(clr, style);
}

const Srgb = @import("color/rgb/srgb.zig").Srgb;
const Cmyk = @import("color/cmyk.zig").Cmyk;

test "TypeFormat styles" {
    var buf: [128]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    const srgb = Srgb(f32).init(0.5, 0.3, 0.1);

    // default: raw values
    try srgb.formatter(.default).format(&w);
    try std.testing.expectEqualStrings("0.5, 0.3, 0.1", buf[0..w.end]);

    w = std.Io.Writer.fixed(&buf);
    // raw: {any} debug dump
    try srgb.formatter(.raw).format(&w);
    const raw_out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, raw_out, ".r = ") != null);

    w = std.Io.Writer.fixed(&buf);
    // pretty: custom formatPretty (cmyk shows percentages)
    const cmyk = Cmyk(f32).init(0.6, 0.5, 0.4, 0.3);
    try cmyk.formatter(.pretty).format(&w);
    const pretty_out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, pretty_out, "%") != null);
}

test "ColorFormat runtime styles" {
    var buf: [128]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    const c = color_mod.Color{ .srgb = Srgb(f32).init(0.5, 0.3, 0.1) };

    // default
    try formatter(c, .default).format(&w);
    try std.testing.expectEqualStrings("0.5, 0.3, 0.1", buf[0..w.end]);

    w = std.Io.Writer.fixed(&buf);
    // pretty
    try formatter(c, .pretty).format(&w);
    const pretty_out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, pretty_out, "Srgb(") != null);

    w = std.Io.Writer.fixed(&buf);
    // raw
    try formatter(c, .raw).format(&w);
    const raw_out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, raw_out, ".r = ") != null);
}

test "ColorFormat with alpha" {
    var buf: [128]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);

    const ac = color_mod.AlphaColor{ .color = .{ .srgb = Srgb(f32).init(0.5, 0.3, 0.1) }, .alpha = 0.75 };

    try formatter(ac, .pretty).format(&w);
    const out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, out, "srgb(") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "0.75") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, ")") != null);
}
