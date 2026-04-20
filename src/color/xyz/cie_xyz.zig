const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const fmt = @import("../../fmt.zig");

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

        pub fn formatter(self: Self, style: fmt.FormatStyle) fmt.TypeFormat(Self) {
            return fmt.TypeFormat(Self).init(self, style);
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

const chroma_testing = @import("../../testing.zig");

const tol: f32 = 0.002;

test "CieXyz(f32) init" {
    const xyz = CieXyz(f32).init(0.5, 0.6, 0.7);
    try std.testing.expectEqual(@as(f32, 0.5), xyz.x);
    try std.testing.expectEqual(@as(f32, 0.6), xyz.y);
    try std.testing.expectEqual(@as(f32, 0.7), xyz.z);
}

test "CieXyz(f32) identity round-trip" {
    const original = CieXyz(f32).init(0.289514, 0.216258, 0.056673);
    const result = CieXyz(f32).fromCieXyz(original.toCieXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "CieXyz(f32) format" {
    var buf: [128]u8 = undefined;
    var w = std.Io.Writer.fixed(&buf);
    const xyz = CieXyz(f32).init(0.5, 0.6, 0.7);
    try xyz.format(&w);
    const out = buf[0..w.end];
    try std.testing.expect(std.mem.indexOf(u8, out, "0.5") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "0.6") != null);
    try std.testing.expect(std.mem.indexOf(u8, out, "0.7") != null);
}
