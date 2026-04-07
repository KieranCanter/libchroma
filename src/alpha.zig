const std = @import("std");
const validation = @import("validation.zig");
const color_formatter = @import("color_formatter.zig");

const Xyz = @import("color_space/xyz.zig").Xyz;

/// Wrapper type that adds an alpha channel to any color type.
/// Alpha is always stored as a float in [0.0, 1.0], even when
/// wrapping a u8-backed RGB type.
pub fn Alpha(comptime ColorType: type) type {
    validation.assertColorInterface(ColorType);

    const AlphaFloat = validation.rgbToFloatType(ColorType.Backing);

    return struct {
        const Self = @This();
        pub const Backing = ColorType.Backing;
        pub const Inner = ColorType;

        color: ColorType,
        a: AlphaFloat,

        pub fn init(color: ColorType, a: AlphaFloat) Self {
            return .{ .color = color, .a = a };
        }

        pub fn initOpaque(color: ColorType) Self {
            return .{ .color = color, .a = 1.0 };
        }

        pub fn setAlpha(self: Self, a: AlphaFloat) Self {
            return .{ .color = self.color, .a = a };
        }

        pub fn stripAlpha(self: Self) ColorType {
            return self.color;
        }

        /// Convert the inner color to a different color type, preserving alpha.
        pub fn convert(self: Self, comptime DestColor: type) Alpha(DestColor) {
            return Alpha(DestColor).init(
                @import("lib.zig").convert(self.color, DestColor),
                self.a,
            );
        }

        // Color interface: delegate to inner color (alpha is lost through XYZ)
        pub fn toXyz(self: Self) Xyz(validation.rgbToFloatType(Backing)) {
            return self.color.toXyz();
        }

        pub fn fromXyz(xyz: Xyz(validation.rgbToFloatType(Backing))) Self {
            return Self.initOpaque(ColorType.fromXyz(xyz));
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try self.color.format(writer);
            try writer.print(", {d}", .{self.a});
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Alpha(", .{});
            try self.color.formatPretty(writer);
            try writer.print(", a={d})", .{self.a});
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const Srgb = @import("color_space/rgb/srgb.zig").Srgb;
const Hsl = @import("color_space/hsl.zig").Hsl;

test "Alpha init and initOpaque" {
    const srgba = Alpha(Srgb(f32)).init(Srgb(f32).init(1, 0, 0), 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), srgba.color.r, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), srgba.a, 0.001);

    const color_opaque = Alpha(Srgb(f32)).initOpaque(Srgb(f32).init(0, 1, 0));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), color_opaque.a, 0.001);
}

test "Alpha setAlpha and stripAlpha" {
    const srgba = Alpha(Srgb(f32)).init(Srgb(f32).init(1, 0, 0), 0.5);

    const changed = srgba.setAlpha(0.8);
    try std.testing.expectApproxEqAbs(@as(f32, 0.8), changed.a, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), changed.color.r, 0.001);

    const stripped = srgba.stripAlpha();
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), stripped.r, 0.001);
}

test "Alpha convert preserves alpha" {
    const srgba = Alpha(Srgb(f32)).init(Srgb(f32).init(0.784, 0.392, 0.196), 0.5);
    const hsla = srgba.convert(Hsl(f32));

    try std.testing.expectApproxEqAbs(@as(f32, 0.5), hsla.a, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 19.999), hsla.color.h.?, 0.002);
}

test "Alpha(Srgb(u8)) alpha is f32" {
    const srgba = Alpha(Srgb(u8)).init(Srgb(u8).init(255, 0, 0), 0.5);
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), srgba.a, 0.001);
    try std.testing.expectEqual(@as(u8, 255), srgba.color.r);
}

test "Alpha fromXyz defaults to opaque" {
    const xyz = Xyz(f32).init(0.2895, 0.2163, 0.0567);
    const srgba = Alpha(Srgb(f32)).fromXyz(xyz);
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), srgba.a, 0.001);
}

test "universal convert preserves alpha (Alpha -> Alpha)" {
    const lib = @import("lib.zig");
    const srgba = Alpha(Srgb(f32)).init(Srgb(f32).init(0.784, 0.392, 0.196), 0.5);
    const hsla = lib.convert(srgba, Alpha(Hsl(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), hsla.a, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 19.999), hsla.color.h.?, 0.002);
}

test "universal convert strips alpha (Alpha -> plain)" {
    const lib = @import("lib.zig");
    const srgba = Alpha(Srgb(f32)).init(Srgb(f32).init(0.784, 0.392, 0.196), 0.5);
    const hsl = lib.convert(srgba, Hsl(f32));
    try std.testing.expectApproxEqAbs(@as(f32, 19.999), hsl.h.?, 0.002);
}

test "universal convert adds default alpha (plain -> Alpha)" {
    const lib = @import("lib.zig");
    const srgb = Srgb(f32).init(0.784, 0.392, 0.196);
    const hsla = lib.convert(srgb, Alpha(Hsl(f32)));
    try std.testing.expectApproxEqAbs(@as(f32, 1.0), hsla.a, 0.001);
    try std.testing.expectApproxEqAbs(@as(f32, 19.999), hsla.color.h.?, 0.002);
}
