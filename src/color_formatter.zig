const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;

pub const ColorFormatStyle = enum {
    default,
    raw,
    pretty,
};

pub fn ColorFormatter(comptime T: type) type {
    assertColorInterface(T);

    return struct {
        const Self = @This();

        color: T,
        style: ColorFormatStyle,

        pub fn init(color: T, style: ColorFormatStyle) Self {
            return .{ .color = color, .style = style };
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            switch (self.style) {
                .raw => {
                    const maybe_last_dot = std.mem.lastIndexOfScalar(u8, @typeName(T), '.');
                    if (maybe_last_dot) |last_dot| {
                        try writer.print("{s}{any}", .{ @typeName(T)[last_dot + 1 ..], self.color });
                    } else {
                        try writer.print("{s}{any}", .{ @typeName(T), self.color });
                    }
                },
                .default => {
                    try self.color.format(writer);
                },
                .pretty => {
                    try self.color.formatPretty(writer);
                },
            }
        }
    };
}
