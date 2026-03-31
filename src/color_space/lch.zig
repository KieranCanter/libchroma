const std = @import("std");
const assertFloatType = @import("../validation.zig").assertFloatType;
const color_formatter = @import("../color_formatter.zig");

const Lab = @import("lab.zig").Lab;
const Xyz = @import("xyz.zig").Xyz;

/// Type to hold a CIE LCH value. ...
///
/// l: ...
/// c: ...
/// h: ...
pub fn Lch(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        l: T,
        c: T,
        h: T,

        pub fn init(l: T, c: T, h: T) Self {
            return .{ .l = l, .c = c, .h = h };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.l, self.c, self.h });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("Lch({s})({d}, {d}, {d})", .{ @typeName(T), self.l, self.c, self.h });
        }

        pub fn toXyz(self: Self) Xyz(T) {
            @compileLog("Implement Lch(T).toXyz()");
            return Xyz(T).init(self.l, self.c, self.h);
        }

        pub fn fromXyz(xyz: anytype) Self {
            @compileLog("Implement Lch(T).fromXyz()");
            return Lch(T).init(xyz.x, xyz.y, xyz.z);
        }

        pub fn toLab(self: Self) Lab(T) {
            @compileLog("Implement Lch(T).toLab()");
            return Lab(T).init(self.l, self.a, self.b);
        }
    };
}
