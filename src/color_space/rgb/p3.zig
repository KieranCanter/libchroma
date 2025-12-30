const std = @import("std");
const validation = @import("../../validation.zig");
const color_formatter = @import("../../color_formatter.zig");
const rgb = @import("../rgb.zig");
const rgbCast = @import("../rgb.zig").rgbCast;
const RgbError = @import("../rgb.zig").RgbError;

const Cmyk = @import("../cmyk.zig").Cmyk;
const Hsi = @import("../hsi.zig").Hsi;
const Hsl = @import("../hsl.zig").Hsl;
const Hsv = @import("../hsv.zig").Hsv;
const Hwb = @import("../hwb.zig").Hwb;
const Xyz = @import("../xyz.zig").Xyz;
const Yxy = @import("../yxy.zig").Yxy;

// Method for computing 3x3 RGB <-> XYZ matrices:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const P3_TO_XYZ: [3][3]f32 = .{
    .{ 0.4865709486482162, 0.26566769316909306, 0.1982172852343625 },
    .{ 0.2289745640697488, 0.6917385218365064, 0.079286914093745 },
    .{ 0.0000000000000000, 0.04511338185890264, 1.043944368900976 },
};
const XYZ_TO_P3: [3][3]f32 = .{
    .{ 2.493496911941425, -0.9313836179191239, -0.40271078445071684 },
    .{ -0.8294889695615747, 1.7626640603183463, 0.023624685841943577 },
    .{ 0.03584583024378447, -0.07617238926804182, 0.9568845240076872 },
};

/// Type to hold a non-linear Display-P3 value. A variant of DCI-P3 (which was originally developed
/// by Digital Cinema Intiatives, LLC for theatrical digital motion picture distribution),
/// Display-P3 was developed by Apple for wide-gamut displays. It covers about 53.6% of the CIE 1931
/// chromaticity gamut.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn P3(comptime T: type) type {
    validation.assertRgbType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;
        const F = validation.rgbToFloatType(T);

        r: T,
        g: T,
        b: T,

        pub fn init(r: T, g: T, b: T) Self {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("P3({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub inline fn cast(self: Self, comptime U: type) P3(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return P3(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearP3(F) = undefined;
            if (T != F) {
                linear = self.cast(F).toLinear();
            } else {
                linear = self.toLinear();
            }

            return Xyz(F).init(
                linear.r * @as(F, P3_TO_XYZ[0][0]) + linear.g * @as(F, P3_TO_XYZ[0][1]) + linear.b * @as(F, P3_TO_XYZ[0][2]),
                linear.r * @as(F, P3_TO_XYZ[1][0]) + linear.g * @as(F, P3_TO_XYZ[1][1]) + linear.b * @as(F, P3_TO_XYZ[1][2]),
                linear.r * @as(F, P3_TO_XYZ[2][0]) + linear.g * @as(F, P3_TO_XYZ[2][1]) + linear.b * @as(F, P3_TO_XYZ[2][2]),
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_P3[0][0]) + xyz.y * @as(U, XYZ_TO_P3[0][1]) + xyz.z * @as(U, XYZ_TO_P3[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_P3[1][0]) + xyz.y * @as(U, XYZ_TO_P3[1][1]) + xyz.z * @as(U, XYZ_TO_P3[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_P3[2][0]) + xyz.y * @as(U, XYZ_TO_P3[2][1]) + xyz.z * @as(U, XYZ_TO_P3[2][2]);

            const linear = LinearP3(U).init(lin_r, lin_g, lin_b);
            const float_p3 = linear.toP3();

            // Cast from backing type of Xyz(U) to backing type of Srgb(T)
            const r = rgbCast(float_p3.r, T);
            const g = rgbCast(float_p3.g, T);
            const b = rgbCast(float_p3.b, T);

            return P3(T).init(r, g, b);
        }

        pub fn toLinear(self: Self) LinearP3(T) {
            return LinearP3(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Same gamma conversion formula as sRGB:
        // https://entropymine.com/imageworsener/srgbformula/
        fn gammaToLinear(val: T) T {
            var fl: F = switch (@typeInfo(T)) {
                .int => @as(f32, @floatFromInt(val)) / 255,
                .float => val,
                else => unreachable,
            };

            var sign: F = 1;
            if (fl < 0) {
                sign = -1;
            }
            const abs: F = fl * sign;

            if (abs <= 0.04045) {
                fl /= 12.92;
            } else {
                fl = sign * std.math.pow(F, (abs + 0.055) / 1.055, 2.4);
            }

            return switch (@typeInfo(T)) {
                .int => @as(u8, @intFromFloat(@round(fl * 255))),
                .float => fl,
                else => unreachable,
            };
        }

        pub fn toCmyk(self: Self) Cmyk(F) {
            return rgb.toCmyk(self);
        }

        pub fn toHsi(self: Self) Hsi(F) {
            return rgb.toHsi(self);
        }

        pub fn toHsl(self: Self) Hsl(F) {
            return rgb.toHsl(self);
        }

        pub fn toHsv(self: Self) Hsv(F) {
            return rgb.toHsv(self);
        }

        pub fn toHwb(self: Self) Hwb(F) {
            return rgb.toHwb(self);
        }
    };
}

/// Type to hold a linearized Display-P3 value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearP3(comptime T: type) type {
    validation.assertRgbType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;
        const F = validation.rgbToFloatType(T);

        r: T,
        g: T,
        b: T,

        pub fn init(r: T, g: T, b: T) Self {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("({d}, {d}, {d})", .{ self.r, self.g, self.b });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("LinearP3({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub inline fn cast(self: Self, comptime U: type) P3(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return LinearP3(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearP3(F) = undefined;
            if (T != F) {
                linear = self.cast(F);
            } else {
                linear = self;
            }

            return Xyz(F).init(
                linear.r * @as(F, P3_TO_XYZ[0][0]) + linear.g * @as(F, P3_TO_XYZ[0][1]) + linear.b * @as(F, P3_TO_XYZ[0][2]),
                linear.r * @as(F, P3_TO_XYZ[1][0]) + linear.g * @as(F, P3_TO_XYZ[1][1]) + linear.b * @as(F, P3_TO_XYZ[1][2]),
                linear.r * @as(F, P3_TO_XYZ[2][0]) + linear.g * @as(F, P3_TO_XYZ[2][1]) + linear.b * @as(F, P3_TO_XYZ[2][2]),
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_P3[0][0]) + xyz.y * @as(U, XYZ_TO_P3[0][1]) + xyz.z * @as(U, XYZ_TO_P3[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_P3[1][0]) + xyz.y * @as(U, XYZ_TO_P3[1][1]) + xyz.z * @as(U, XYZ_TO_P3[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_P3[2][0]) + xyz.y * @as(U, XYZ_TO_P3[2][1]) + xyz.z * @as(U, XYZ_TO_P3[2][2]);

            const linear = LinearP3(U).init(lin_r, lin_g, lin_b);

            // Cast from backing type of Xyz(U) to backing type of LinearSrgb(T)
            const r = rgbCast(linear.r, T);
            const g = rgbCast(linear.g, T);
            const b = rgbCast(linear.b, T);

            return LinearP3(T).init(r, g, b);
        }

        pub fn toP3(self: Self) P3(T) {
            return P3(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }

        // Same gamma conversion formula as sRGB:
        // https://entropymine.com/imageworsener/srgbformula/
        fn linearToGamma(val: T) T {
            var fl: F = switch (@typeInfo(T)) {
                .int => @as(f32, @floatFromInt(val)) / 255,
                .float => val,
                else => unreachable,
            };

            var sign: F = 1;
            if (fl < 0) {
                sign = -1;
            }
            const abs: F = fl * sign;

            if (fl <= 0.0031308) {
                fl *= 12.92;
            } else {
                fl = sign * (1.055 * std.math.pow(F, abs, 1.0 / 2.4) - 0.055);
            }

            return switch (@typeInfo(T)) {
                .int => @as(u8, @intFromFloat(@round(fl * 255))),
                .float => fl,
                else => unreachable,
            };
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

// ===========================
// P3
// ===========================

// ===========================
// LinearP3
// ===========================
