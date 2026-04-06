const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;
const colorSpaceName = @import("validation.zig").colorSpaceName;
const color_formatter = @import("color_formatter.zig");

const Srgb = @import("color_space/rgb/srgb.zig").Srgb;

/// Wrapper type to add an alpha channel to any type.
///
/// color: contained value adhering to the Color interface contract
/// alpha: value of the alpha channel
pub fn Alpha(color: anytype) type {
    const C = @TypeOf(color);
    assertColorInterface(C);

    return struct {
        const Self = @This();
        pub const Backing = C.Backing;

        color: C,
        alpha: Backing,

        pub fn init(alpha: Backing) Self {
            return .{ .color = color, .alpha = alpha };
        }

        pub fn stripAlpha(self: Self) C {
            return self.color;
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{f}, {d}", .{ self.color, self.alpha });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            const typeName = colorSpaceName(C);
            try writer.print("Alpha({s})({f})", .{ typeName, self });
        }

        pub fn toXyz() void {
            return;
        }

        pub fn fromXyz() void {
            return;
        }
    };
}
