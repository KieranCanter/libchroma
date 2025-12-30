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
const REC2020_TO_XYZ: [3][3]f32 = .{
    .{ 0.6369580483012914, 0.14461690358620832, 0.1688809751641721 },
    .{ 0.2627002120112671, 0.6779980715188708, 0.05930171646986196 },
    .{ 0.000000000000000, 0.028072693049087428, 1.060985057710791 },
};
const XYZ_TO_REC2020: [3][3]f32 = .{
    .{ 1.716651187971268, -0.355670783776392, -0.253366281373660 },
    .{ -0.666684351832489, 1.616481236634939, 0.0157685458139111 },
    .{ 0.017639857445311, -0.042770613257809, 0.942103121235474 },
};

/// Type to hold a non-linear Rec. 2020 value. This is a display-referred variant that uses the EOTF
/// specified in the Rec. 1886 spec (2.4 gamma). Rec. 2020 covers about 75.8% of the CIE 1931
/// chromaticity gamut.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Rec2020(comptime T: type) type {
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
            try writer.print("Rec2020({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub inline fn cast(self: Self, comptime U: type) Rec2020(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return Rec2020(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearRec2020(F) = undefined;
            if (T != F) {
                linear = self.cast(F).toLinear();
            } else {
                linear = self.toLinear();
            }

            return Xyz(F).init(
                linear.r * @as(F, REC2020_TO_XYZ[0][0]) + linear.g * @as(F, REC2020_TO_XYZ[0][1]) + linear.b * @as(F, REC2020_TO_XYZ[0][2]),
                linear.r * @as(F, REC2020_TO_XYZ[1][0]) + linear.g * @as(F, REC2020_TO_XYZ[1][1]) + linear.b * @as(F, REC2020_TO_XYZ[1][2]),
                linear.r * @as(F, REC2020_TO_XYZ[2][0]) + linear.g * @as(F, REC2020_TO_XYZ[2][1]) + linear.b * @as(F, REC2020_TO_XYZ[2][2]),
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_REC2020[0][0]) + xyz.y * @as(U, XYZ_TO_REC2020[0][1]) + xyz.z * @as(U, XYZ_TO_REC2020[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_REC2020[1][0]) + xyz.y * @as(U, XYZ_TO_REC2020[1][1]) + xyz.z * @as(U, XYZ_TO_REC2020[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_REC2020[2][0]) + xyz.y * @as(U, XYZ_TO_REC2020[2][1]) + xyz.z * @as(U, XYZ_TO_REC2020[2][2]);

            const linear = LinearRec2020(U).init(lin_r, lin_g, lin_b);
            const float_rec2020 = linear.toRec2020();

            // Cast from backing type of Xyz(U) to backing type of Srgb(T)
            const r = rgbCast(float_rec2020.r, T);
            const g = rgbCast(float_rec2020.g, T);
            const b = rgbCast(float_rec2020.b, T);

            return Rec2020(T).init(r, g, b);
        }

        pub fn toLinear(self: Self) LinearRec2020(T) {
            return LinearRec2020(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Rec. 2020 EOTF is the same as Rec. 1886, located in Annex 1:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.1886-0-201103-I!!PDF-E.pdf
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
            fl = sign * std.math.pow(F, abs, 1.0 / 2.4);

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

/// Type to hold a non-linear Rec. 2020 value. This is a scene-referred variant that uses the OETF
/// specified in the Rec. 2020 spec.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Rec2020Scene(comptime T: type) type {
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
            try writer.print("Rec2020Scene({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub inline fn cast(self: Self, comptime U: type) Rec2020Scene(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return Rec2020Scene(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearRec2020(F) = undefined;
            if (T != F) {
                linear = self.cast(F).toLinear();
            } else {
                linear = self.toLinear();
            }

            return Xyz(F).init(
                linear.r * @as(F, REC2020_TO_XYZ[0][0]) + linear.g * @as(F, REC2020_TO_XYZ[0][1]) + linear.b * @as(F, REC2020_TO_XYZ[0][2]),
                linear.r * @as(F, REC2020_TO_XYZ[1][0]) + linear.g * @as(F, REC2020_TO_XYZ[1][1]) + linear.b * @as(F, REC2020_TO_XYZ[1][2]),
                linear.r * @as(F, REC2020_TO_XYZ[2][0]) + linear.g * @as(F, REC2020_TO_XYZ[2][1]) + linear.b * @as(F, REC2020_TO_XYZ[2][2]),
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_REC2020[0][0]) + xyz.y * @as(U, XYZ_TO_REC2020[0][1]) + xyz.z * @as(U, XYZ_TO_REC2020[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_REC2020[1][0]) + xyz.y * @as(U, XYZ_TO_REC2020[1][1]) + xyz.z * @as(U, XYZ_TO_REC2020[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_REC2020[2][0]) + xyz.y * @as(U, XYZ_TO_REC2020[2][1]) + xyz.z * @as(U, XYZ_TO_REC2020[2][2]);

            const linear = LinearRec2020(U).init(lin_r, lin_g, lin_b);
            const float_rec2020scene = linear.toRec2020Scene();

            // Cast from backing type of Xyz(U) to backing type of Srgb(T)
            const r = rgbCast(float_rec2020scene.r, T);
            const g = rgbCast(float_rec2020scene.g, T);
            const b = rgbCast(float_rec2020scene.b, T);

            return Rec2020Scene(T).init(r, g, b);
        }

        pub fn toLinear(self: Self) LinearRec2020(T) {
            return LinearRec2020(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Rec. 2020 OETF is defined in Table 4:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2020-2-201510-I!!PDF-E.pdf
        fn gammaToLinear(val: T) T {
            var fl: F = switch (@typeInfo(T)) {
                .int => @as(f32, @floatFromInt(val)) / 255,
                .float => val,
                else => unreachable,
            };

            const alpha: F = 1.09929682680944;
            const beta: F = 0.018053968510807;

            var sign: F = 1;
            if (fl < 0) {
                sign = -1;
            }
            const abs: F = fl * sign;

            if (abs < beta) {
                fl *= 4.5;
            } else {
                fl = sign * (alpha * std.math.pow(F, abs, 0.45) - (alpha - 1));
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

/// Type to hold a linearized Rec. 2020 value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearRec2020(comptime T: type) type {
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
            try writer.print("LinearRec2020({s})({d}, {d}, {d})", .{ @typeName(T), self.r, self.g, self.b });
        }

        pub inline fn cast(self: Self, comptime U: type) LinearRec2020(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return LinearRec2020(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearRec2020(F) = undefined;
            if (T != F) {
                linear = self.cast(F);
            } else {
                linear = self;
            }

            return Xyz(F).init(
                linear.r * @as(F, REC2020_TO_XYZ[0][0]) + linear.g * @as(F, REC2020_TO_XYZ[0][1]) + linear.b * @as(F, REC2020_TO_XYZ[0][2]),
                linear.r * @as(F, REC2020_TO_XYZ[1][0]) + linear.g * @as(F, REC2020_TO_XYZ[1][1]) + linear.b * @as(F, REC2020_TO_XYZ[1][2]),
                linear.r * @as(F, REC2020_TO_XYZ[2][0]) + linear.g * @as(F, REC2020_TO_XYZ[2][1]) + linear.b * @as(F, REC2020_TO_XYZ[2][2]),
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_REC2020[0][0]) + xyz.y * @as(U, XYZ_TO_REC2020[0][1]) + xyz.z * @as(U, XYZ_TO_REC2020[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_REC2020[1][0]) + xyz.y * @as(U, XYZ_TO_REC2020[1][1]) + xyz.z * @as(U, XYZ_TO_REC2020[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_REC2020[2][0]) + xyz.y * @as(U, XYZ_TO_REC2020[2][1]) + xyz.z * @as(U, XYZ_TO_REC2020[2][2]);

            const linear = LinearRec2020(U).init(lin_r, lin_g, lin_b);

            // Cast from backing type of Xyz(U) to backing type of LinearSrgb(T)
            const r = rgbCast(linear.r, T);
            const g = rgbCast(linear.g, T);
            const b = rgbCast(linear.b, T);

            return LinearRec2020(T).init(r, g, b);
        }

        pub fn toRec2020(self: Self) Rec2020(T) {
            return Rec2020(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }
        
        pub fn toRec2020Scene(self: Self) Rec2020Scene(T) {
            return Rec2020Scene(T).init(
                linearToGammaOetf(self.r),
                linearToGammaOetf(self.g),
                linearToGammaOetf(self.b),
            );
        }

        // Rec. 2020 EOTF is the same as Rec. 1886, located in Annex 1:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.1886-0-201103-I!!PDF-E.pdf
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
            fl = sign * std.math.pow(F, abs, 2.4);

            return switch (@typeInfo(T)) {
                .int => @as(u8, @intFromFloat(@round(fl * 255))),
                .float => fl,
                else => unreachable,
            };
        }

        // Rec. 2020 OETF is defined in Table 4:
        // https://www.itu.int/dms_pubrec/itu-r/rec/bt/R-REC-BT.2020-2-201510-I!!PDF-E.pdf
        fn linearToGammaOetf(val: T) T {
            var fl: F = switch (@typeInfo(T)) {
                .int => @as(f32, @floatFromInt(val)) / 255,
                .float => val,
                else => unreachable,
            };

            const alpha: F = 1.09929682680944;
            const beta: F = 0.018053968510807;

            var sign: F = 1;
            if (fl < 0) {
                sign = -1;
            }
            const abs: F = fl * sign;

            if (abs <= beta * 4.5) {
                fl /= 4.5;
            } else {
                fl = sign * std.math.pow(F, (abs + alpha - 1) / alpha, 1.0 / 0.45);
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
// Rec2020
// ===========================

// ===========================
// Rec2020Scene
// ===========================

// ===========================
// LinearRec2020
// ===========================
