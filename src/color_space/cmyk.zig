const std = @import("std");
const validation = @import("../validation.zig");
const color_formatter = @import("../color_formatter.zig");

const Srgb = @import("rgb/srgb.zig").Srgb;
const Xyz = @import("xyz.zig").Xyz;
const ChromaError = @import("../lib.zig").ChromaError;

/// Type to hold a CMYK value.
///
/// c: cyan value in [0.0, 1.0]
/// m: magenta value in [0.0, 1.0]
/// y: yellow value in [0.0, 1.0]
/// k: black value in [0.0, 1.0]
pub fn Cmyk(comptime T: type) type {
    validation.assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        c: T,
        m: T,
        y: T,
        k: T,

        pub fn init(c: T, m: T, y: T, k: T) Self {
            return .{ .c = c, .m = m, .y = y, .k = k };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d}, {d})", .{ self.c, self.m, self.y, self.k });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            const c_percent = self.c * 100;
            const m_percent = self.m * 100;
            const y_percent = self.y * 100;
            const k_percent = self.k * 100;
            try writer.print("Cmyk({s})({d:.1}%, {d:.1}%, {d:.1}%, {d:.1}%)", .{ @typeName(T), c_percent, m_percent, y_percent, k_percent });
        }

        // Gray Component Replacement
        pub fn gcr(self: Self, strength: T) ChromaError!void {
            if (strength < 0 or strength > 1) {
                return ChromaError.OutOfRange;
            }

            const gray = @min(self.c, self.m, self.y) * strength;

            self.c -= gray;
            self.m -= gray;
            self.y -= gray;
            self.k += gray;
        }

        // Under Color Removal
        pub fn ucr(self: Self) void {
            return self.gcr(1);
        }

        // Under Color Addition
        pub fn uca(self: Self, strength: T) ChromaError!void {
            if (strength < 0 or strength > 1) {
                return ChromaError.OutOfRange;
            }

            const removed = self.k * strength;

            self.c += removed;
            self.m += removed;
            self.y += removed;
            self.k -= removed;
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return self.toSrgb().toXyz();
        }

        pub fn fromXyz(xyz: anytype) Self {
            return Srgb(T).fromXyz(xyz).toCmyk();
        }

        // Formula for CMYK -> sRGB conversion:
        // https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
        pub fn toSrgb(self: Self) @TypeOf(Srgb(T)) {
            const r = (1 - self.c) * (1 - self.k);
            const g = (1 - self.m) * (1 - self.k);
            const b = (1 - self.y) * (1 - self.k);

            return Srgb(T).init(r, g, b);
        }
    };
}

// ///////////////////////////////////////////////////////////////////////// //
// ///////////////////////////////   TESTS   /////////////////////////////// //
// ///////////////////////////////////////////////////////////////////////// //

// Tolerances are used for some comparisons to allow inexact approximation checks:
// * For f32, when truncated to 3 decimal places, compared values should differ by no more than
// 0.001.
// * For f64, when truncated to 6 decimal places, compared values should differ by no more
// than 0.000001.
//
// To prevent having to manually truncate all values to the specified number of decimal places,
// 0.002 and 0.000002 are used as tolerances. For example, if we have an expected value of 0.392156
// and an actual value of 0.39215732995152763, this would technically fail with a 0.000001 tolerance
// because at the sixth decimal place, there is about a 0.0000013 difference, but if we truncated
// the actual value to six decimal places, it would be 0.392157, which only has a 0.000001
// difference with our expected value.

// //////////////////////// //
// ////////  Cmyk  //////// //
// //////////////////////// //

test "Cmyk formatting" {
    const alloc = std.testing.allocator;

    const cmyk_f32 = Cmyk(f32).init(0.6, 0.5, 0.4, 0.3);
    var exp_format: []const u8 = "(0.6, 0.5, 0.4, 0.3)";
    var exp_default: []const u8 = "(0.6, 0.5, 0.4, 0.3)";
    var exp_raw: []const u8 = "Cmyk(f32).{ .c = 0.6, .m = 0.5, .y = 0.4, .k = 0.3 }";
    var exp_pretty: []const u8 = "Cmyk(f32)(60.0%, 50.0%, 40.0%, 30.0%)";
    var act_format: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f32});
    var act_default: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f32.formatter(.default)});
    var act_raw: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f32.formatter(.raw)});
    var act_pretty: []const u8 = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f32.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);

    const cmyk_f64 = Cmyk(f64).init(0.6, 0.5, 0.4, 0.3);
    exp_format= "(0.6, 0.5, 0.4, 0.3)";
    exp_default = "(0.6, 0.5, 0.4, 0.3)";
    exp_raw = "Cmyk(f64).{ .c = 0.6, .m = 0.5, .y = 0.4, .k = 0.3 }";
    exp_pretty = "Cmyk(f64)(60.0%, 50.0%, 40.0%, 30.0%)";
    act_format = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f64});
    act_default = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f64.formatter(.default)});
    act_raw = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f64.formatter(.raw)});
    act_pretty = try std.fmt.allocPrint(alloc, "{f}", .{cmyk_f64.formatter(.pretty)});
    try std.testing.expectEqualStrings(exp_format, act_format);
    try std.testing.expectEqualStrings(exp_default, act_default);
    try std.testing.expectEqualStrings(exp_raw, act_raw);
    try std.testing.expectEqualStrings(exp_pretty, act_pretty);

    alloc.free(act_format);
    alloc.free(act_default);
    alloc.free(act_raw);
    alloc.free(act_pretty);
}

//test "Cmyk(f32) to" {
//    const tolerance = 0.002;
//
//    var srgb = Cmyk(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
//    var expected = Cmyk(f32).init(0.578, 0.127, 0.032);
//    var actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//
//    srgb = Cmyk(f32).init(0, 0, 0);
//    expected = Cmyk(f32).init(0, 0, 0);
//    actual = srgb.to();
//    try std.testing.expectEqual(expected, actual);
//
//    srgb = Cmyk(f32).init(1, 1, 1);
//    expected = Cmyk(f32).init(1, 1, 1);
//    actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//
//    srgb = Cmyk(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
//    expected = Cmyk(f32).init(0.008, 0.577, 0.026);
//    actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//}
//
//test "Cmyk(f64) to" {
//    const tolerance = 0.000002;
//
//    var srgb = Cmyk(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
//    var expected = Cmyk(f64).init(0.577580, 0.127438, 0.031896);
//    var actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//
//    srgb = Cmyk(f64).init(0, 0, 0);
//    expected = Cmyk(f64).init(0, 0, 0);
//    actual = srgb.to();
//    try std.testing.expectEqual(expected, actual);
//
//    srgb = Cmyk(f64).init(1, 1, 1);
//    expected = Cmyk(f64).init(1, 1, 1);
//    actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//
//    srgb = Cmyk(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
//    expected = Cmyk(f64).init(0.008023, 0.577580, 0.026241);
//    actual = srgb.to();
//    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
//}
