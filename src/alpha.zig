const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;
const color_formatter = @import("color_formatter.zig");

/// Wrapper type to add an alpha channel to any type
///
/// color: contained value adhering to the Color interface contract
/// alpha: value of the alpha channel
pub fn Alpha(comptime C: type) type {
    assertColorInterface(C);

    return struct {
        const Self = @This();

        color: C,
        alpha: f32,

        pub fn init(color: C, alpha: f32) Self {
            return .{ .color = color, .alpha = alpha };
        }

        pub fn initOpaque(color: C) Self {
            return .{ .color = color, .alpha = 0 }; // TODO: does opaque mean translucent?
        }

        pub fn stripAlpha(self: Self) C {
            return self.color;
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            // FIX: kind of awkward format e.g. `(r, g, b), (alpha)`
            // Would be better as `(r, g, b, alpha)` (maybe I should remove the included parens)
            try writer.print("{f}, (d)", .{ self.color.format(), self.alpha });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            // FIX: @typeName(C) will result in the long full namespace of C
            // Can I get backing type T from C somehow?
            try writer.print("Xyz({s})({d}, {d}, {d})", .{ @typeName(C), self.x, self.y, self.z });
        }
    };
}

/// Type to hold a CIE XYZ value. The central funnel for converting across the common color spaces
/// like sRGB to the CIE LAB color spaces.
///
/// x: mix of the three CIE RGB curves in [0.0, inf)
/// y: luminance value in [0.0, inf)
/// z: quasi-blue value in [0.0, inf)
pub fn Xyz(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        x: T,
        y: T,
        z: T,

        pub fn init(x: T, y: T, z: T) Self {
            return .{ .x = x, .y = y, .z = z };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.x, self.y, self.z });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Xyz({s})({d}, {d}, {d})", .{ @typeName(T), self.x, self.y, self.z });
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self;
        }

        pub fn fromXyz(xyz: anytype) Self {
            return xyz;
        }
    };
}
