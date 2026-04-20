const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const color_formatter = @import("../../color_formatter.zig");

/// CIE XYZ color, the central interchange space.
/// `x`: mix of CIE RGB curves in [0, inf)
/// `y`: luminance in [0, inf)
/// `z`: quasi-blue in [0, inf)
pub fn CieXyz(comptime T: type) type {
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
            try writer.print("{d}, {d}, {d}", .{ self.x, self.y, self.z });
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self;
        }

        pub fn fromCieXyz(xyz: anytype) Self {
            return .{ .x = @floatCast(xyz.x), .y = @floatCast(xyz.y), .z = @floatCast(xyz.z) };
        }
    };
}
