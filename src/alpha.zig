const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;
const color_formatter = @import("color_formatter.zig");

/// Wrapper type to add an alpha channel to any type.
///
/// color: contained value adhering to the Color interface contract
/// alpha: value of the alpha channel
pub fn Alpha(color: anytype) type {
    const C = @TypeOf(color);
    assertColorInterface(C);

    return struct {
        const Self = @This();
        const T = C.Backing;

        color: C,
        alpha: T,

        pub fn init(alpha: T) Self {
            return .{ .color = color, .alpha = alpha };
        }

        pub fn initOpaque() Self {
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
            try writer.print("Alpha({s})({d}, {d}, {d})", .{ @typeName(C), self.x, self.y, self.z });
        }
    };
}
