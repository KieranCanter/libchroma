const std = @import("std");
const assertColorInterface = @import("validation.zig").assertColorInterface;
const colorSpaceName = @import("validation.zig").colorSpaceName;

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
                    const typeName = colorSpaceName(Self);
                    try writer.print("{s}{any}", .{ typeName, self.color });
                },
                .default => {
                    try self.color.format(writer);
                },
                .pretty => {
                    // Call type's formatPretty() if it has one
                    if (@hasDecl(T, "formatPretty"))
                        return @call(.auto, @field(T, "formatPretty"), .{self.color, writer});

                    // Otherwise fall back to wrapping
                    const typeName = colorSpaceName(Self);
                    try writer.print("{s}({f})", .{ typeName, self.color });
                },
            }
        }
    };
}
