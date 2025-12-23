const std = @import("std");
const validation = @import("../validation.zig");

const Cmyk = @import("Cmyk.zig").Cmyk;
const Hsi = @import("Hsi.zig").Hsi;
const Hsl = @import("Hsl.zig").Hsl;
const Hsv = @import("Hsv.zig").Hsv;
const Hwb = @import("Hwb.zig").Hwb;
const Xyz = @import("Xyz.zig").Xyz;
const Yxy = @import("Yxy.zig").Yxy;

// Matrix for linearizing sRGB during sRGB-> XYZ conversion:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const SRGB_TO_XYZ: [3][3]f32 = .{
    .{ 0.4124564, 0.3575761, 0.1804375 },
    .{ 0.2126729, 0.7151522, 0.0721750 },
    .{ 0.0193339, 0.1191920, 0.9503041 },
};

// Matrices for various RGB <-> XYZ conversions with linearized RGB values:
// http://www.brucelindbloom.com/index.html?Eqn_RGB_XYZ_Matrix.html
const XYZ_TO_SRGB: [3][3]f32 = .{
    .{ 3.2404542, -1.5371385, -0.4985314 },
    .{ -0.9692660, 1.8760108, 0.0415560 },
    .{ 0.0556434, -0.2040259, 1.0572252 },
};

pub const SrgbError = error{
    InvalidHexString,
};

fn rgbCast(val: anytype, comptime U: type) U {
    const T = @TypeOf(val);
    validation.assertRgbType(U);

    if (T == U) {
        return val;
    }

    return switch (T) {
        u8 => switch (U) {
            f32, f64 => @as(U, @floatFromInt(val)) / 255,
            else => unreachable,
        },
        f32 => switch (U) {
            u8 => @as(u8, @intFromFloat(@round(val * 255))),
            f64 => @as(f64, @floatCast(val)),
            else => unreachable,
        },
        f64 => switch (U) {
            u8 => @as(u8, @intFromFloat(@round(val * 255))),
            f32 => @as(f32, @floatCast(val)),
            else => unreachable,
        },
        else => unreachable,
    };
}

/// Type to hold a non-linear sRGB value. Generic "RGB" most commonly refers to sRGB.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn Srgb(comptime T: type) type {
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

        pub inline fn cast(self: Self, comptime U: type) Srgb(U) {
            const r = rgbCast(self.r, U);
            const g = rgbCast(self.g, U);
            const b = rgbCast(self.b, U);
            return Srgb(U).init(r, g, b);
        }

        pub fn toXyz(self: Self) Xyz(F) {
            var linear: LinearSrgb(F) = undefined;
            if (T != F) {
                linear = self.cast(F).toLinear();
            } else {
                linear = self.toLinear();
            }

            return Xyz(F).init(
                linear.r * SRGB_TO_XYZ[0][0] + linear.g * SRGB_TO_XYZ[0][1] + linear.b * SRGB_TO_XYZ[0][2],
                linear.r * SRGB_TO_XYZ[1][0] + linear.g * SRGB_TO_XYZ[1][1] + linear.b * SRGB_TO_XYZ[1][2],
                linear.r * SRGB_TO_XYZ[2][0] + linear.g * SRGB_TO_XYZ[2][1] + linear.b * SRGB_TO_XYZ[2][2],
            );
        }

        pub fn fromXyz(xyz: anytype) Self {
            const U = @TypeOf(xyz).Backing;

            const lin_r = xyz.x * @as(U, XYZ_TO_SRGB[0][0]) + xyz.y * @as(U, XYZ_TO_SRGB[0][1]) + xyz.z * @as(U, XYZ_TO_SRGB[0][2]);
            const lin_g = xyz.x * @as(U, XYZ_TO_SRGB[1][0]) + xyz.y * @as(U, XYZ_TO_SRGB[1][1]) + xyz.z * @as(U, XYZ_TO_SRGB[1][2]);
            const lin_b = xyz.x * @as(U, XYZ_TO_SRGB[2][0]) + xyz.y * @as(U, XYZ_TO_SRGB[2][1]) + xyz.z * @as(U, XYZ_TO_SRGB[2][2]);

            const linear = LinearSrgb(U).init(lin_r, lin_g, lin_b);
            const float_srgb = linear.toSrgb();

            // Cast from backing type of Xyz(U) to backing type of Srgb(T)
            const r = rgbCast(float_srgb.r, T);
            const g = rgbCast(float_srgb.g, T);
            const b = rgbCast(float_srgb.b, T);

            return Srgb(T).init(r, g, b);
        }

        pub fn toLinear(self: Self) LinearSrgb(T) {
            return LinearSrgb(T).init(
                gammaToLinear(self.r),
                gammaToLinear(self.g),
                gammaToLinear(self.b),
            );
        }

        // Formulae for sRGB <-> Linear conversions:
        // https://entropymine.com/imageworsener/srgbformula/
        fn gammaToLinear(val: T) T {
            var fl = switch (T) {
                u8 => @as(f32, @floatFromInt(val)) / 255,
                f32, f64 => val,
                else => unreachable,
            };

            if (fl <= 0.04045) {
                fl /= 12.92;
            } else {
                fl = std.math.pow(@TypeOf(fl), (fl + 0.055) / 1.055, 2.4);
            }

            return switch (T) {
                u8 => @as(u8, @intFromFloat(@round(fl * 255))),
                f32, f64 => fl,
                else => unreachable,
            };
        }

        // Formula for sRGB -> CMYK conversion:
        // https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
        pub fn toCmyk(self: Self) Cmyk(F) {
            const r, const g, const b = self.rgbToFloatType();

            const k = 1.0 - @max(r, g, b);
            if (k == 1.0) { // Avoid division by 0
                return Cmyk(F).init(0, 0, 0, k);
            }
            const c = (1.0 - r - k) / (1.0 - k);
            const m = (1.0 - g - k) / (1.0 - k);
            const y = (1.0 - b - k) / (1.0 - k);

            return Cmyk(F).init(c, m, y, k);
        }

        pub fn toHex(self: Self) HexSrgb {
            return HexSrgb.initFromSrgb(self);
        }

        // Formula for sRGB -> HSI conversion:
        // https://www.rmuti.ac.th/user/kedkarn/impfile/RGB_to_HSI.pdf
        pub fn toHsi(self: Self) Hsi(F) {
            const r, const g, const b = self.rgbToFloatType();

            const xmax = @max(r, g, b);
            const xmin = @min(r, g, b);
            const chroma = xmax - xmin;

            // Intensity
            const i = (r + g + b) / 3.0;

            // Saturation
            var s: F = 0.0;
            if (i != 0) {
                s = 1.0 - (xmin / i);
            }

            // Hue
            var h: ?F = null;
            if (chroma != 0) {
                h = computeHue(r, g, b, xmax, xmin);
            }

            return Hsi(F).init(h, s, i);
        }

        // Formula for sRGB -> HSL conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
        pub fn toHsl(self: Self) Hsl(F) {
            const r, const g, const b = self.rgbToFloatType();

            const xmax = @max(r, g, b);
            const xmin = @min(r, g, b);
            const chroma = xmax - xmin;

            // Lightness
            const l = (xmax + xmin) / 2.0;

            // Hue
            var h: ?F = null;
            if (chroma != 0) {
                h = computeHue(r, g, b, xmax, xmin);
            }

            // Saturation
            var s: F = 0.0;
            if (l != 0 and l != 1) {
                s = chroma / (1.0 - @abs(2.0 * l - 1.0));
            }

            return Hsl(F).init(h, s, l);
        }

        // Formula for sRGB -> HSL conversion:
        // https://en.wikipedia.org/wiki/HSL_and_HSV#From_RGB
        pub fn toHsv(self: Self) Hsv(F) {
            const r, const g, const b = self.rgbToFloatType();

            // Value
            const xmax = @max(r, g, b);
            const xmin = @min(r, g, b);
            const chroma = xmax - xmin;

            // Hue
            var h: ?F = null;
            if (chroma != 0) {
                h = computeHue(r, g, b, xmax, xmin);
            }

            // Saturation
            var s: F = 0.0;
            if (xmax != 0) {
                s = chroma / xmax;
            }

            return Hsv(F).init(h, s, xmax);
        }

        // Formula for sRGB -> HWB conversion:
        // https://www.w3.org/TR/css-color-4/#rgb-to-hwb
        pub fn toHwb(self: Self) Hwb(F) {
            const r, const g, const b = self.rgbToFloatType();

            const xmax = @max(r, g, b);
            const xmin = @min(r, g, b);

            // Whiteness
            const white = xmin;

            // Blackness
            const black = 1.0 - xmax;

            // Hue
            const epsilon: F = 1 / 100000; // for floating point error
            var h: ?F = null;
            if (white + black < 1 - epsilon) {
                h = computeHue(r, g, b, xmax, xmin);
            }

            return Hwb(F).init(h, white, black);
        }

        /// Typically, the hue of HSI, HSL, HSV, and HWB is calulcated via an trigonemetric algorithm as
        /// such:
        ///
        /// ```zig
        /// const numerator = 0.5 * ((self.r - self.g) + (self.r - self.b));
        /// const denominator = std.math.sqrt((self.r - self.g) * (self.r - self.g) + (self.r - self.b) * (self.g - self.b));
        /// var h = std.math.acos(numerator / denominator) * 180 / std.math.pi;
        /// if (self.b > self.g) {
        ///     h = 360.0 - h;
        /// }
        /// ```
        ///
        /// or in plaintext:
        ///
        /// ```
        /// N = 0.5[(R - G) + (R - B)] = R - ((G + B) / 2)
        /// D = sqrt(pow(R - G, 2) + (R - B) * (G - B))
        /// Hue = acos(N / D)
        /// ```
        ///
        /// To avoid expensive functions like acos() and sqrt(), we can use the max RGB channel and min
        /// RGB channel to calculate the hue instead. When we consider that each 60° sector will have a
        /// most dominant channel and least dominant channel, the above cosine ratio can be simplified
        /// to a linear function, where `C = max(R, G, B) - min(R, G, B)` represents the chroma and the
        /// subscript to `Hue` represents the most dominant channel.
        ///
        /// ```
        /// Hue_R = 60 * (((G - B) / C) % 6)
        /// Hue_G = 60 * ((B - R) / C) + 2)
        /// Hue_B = 60 * ((R - B) / C) + 4)
        /// ```
        ///
        /// Note:
        /// * Each one of ((R, G, B) - (R, G, B) / C) will be in the range [-1, 1]
        /// * `Hue_R` represents the 300°-60° sector, so it has no offset, but must be guaranteed to be
        /// within positive bounds, thus the modulo is used to ensure this (alternatively you could
        /// conditionally check for negativity and add 360°)
        /// * `Hue_G` represents the 60°-180° sector, so it is offset by 2 (120°)
        /// * `Hue_B` represents the 180°-300° sector, so it is offset by 4 (240°)
        fn computeHue(r: F, g: F, b: F, xmax: F, xmin: F) F {
            const chroma = xmax - xmin;
            var h: F = 0;
            if (xmax == r) {
                h = 60.0 * @mod((g - b) / chroma, 6);
            } else if (xmax == g) {
                h = 60.0 * ((b - r) / chroma + 2.0);
            } else if (xmax == b) {
                h = 60.0 * ((r - g) / chroma + 4.0);
            } else {
                unreachable;
            }

            return h;
        }

        // If T is u8, convert to f32, otherwise use existing float type
        fn rgbToFloatType(self: Self) struct { F, F, F } {
            if (T != F) {
                const casted = self.cast(F);
                return .{ casted.r, casted.g, casted.b };
            } else {
                return .{ self.r, self.g, self.b };
            }
        }
    };
}

/// Type to hold a linearized sRGB value.
///
/// r: red value in [0.0, 1.0] (float) or [0, 255] (u8)
/// g: green value in [0.0, 1.0] (float) or [0, 255] (u8)
/// b: blue value in [0.0, 1.0] (float) or [0, 255] (u8)
pub fn LinearSrgb(comptime T: type) type {
    validation.assertRgbType(T);

    return struct {
        const Self = @This();
        r: T,
        g: T,
        b: T,

        pub fn init(r: T, g: T, b: T) Self {
            return .{ .r = r, .g = g, .b = b };
        }

        pub fn toXyz(self: Self) Xyz(T) {
            return Xyz(T).init(
                self.r * SRGB_TO_XYZ[0][0] + self.g * SRGB_TO_XYZ[0][1] + self.b * SRGB_TO_XYZ[0][2],
                self.r * SRGB_TO_XYZ[1][0] + self.g * SRGB_TO_XYZ[1][1] + self.b * SRGB_TO_XYZ[1][2],
                self.r * SRGB_TO_XYZ[2][0] + self.g * SRGB_TO_XYZ[2][1] + self.b * SRGB_TO_XYZ[2][2],
            );
        }

        pub fn fromXyz(xyz: Xyz(T)) Self {
            return Self.init(
                xyz.x * XYZ_TO_SRGB[0][0] + xyz.y * XYZ_TO_SRGB[0][1] + xyz.z * XYZ_TO_SRGB[0][2],
                xyz.x * XYZ_TO_SRGB[1][0] + xyz.y * XYZ_TO_SRGB[1][1] + xyz.z * XYZ_TO_SRGB[1][2],
                xyz.x * XYZ_TO_SRGB[2][0] + xyz.y * XYZ_TO_SRGB[2][1] + xyz.z * XYZ_TO_SRGB[2][2],
            );
        }

        pub fn toSrgb(self: Self) Srgb(T) {
            return Srgb(T).init(
                linearToGamma(self.r),
                linearToGamma(self.g),
                linearToGamma(self.b),
            );
        }

        // Formulae for sRGB <-> Linear conversions:
        // https://entropymine.com/imageworsener/srgbformula/
        fn linearToGamma(val: T) T {
            var fl = switch (T) {
                u8 => @as(f32, @floatFromInt(val)) / 255,
                f32, f64 => val,
                else => unreachable,
            };

            if (fl <= 0.0031308) {
                fl *= 12.92;
            } else {
                fl = 1.055 * std.math.pow(@TypeOf(fl), fl, 1.0 / 2.4) - 0.055;
            }

            return switch (T) {
                u8 => @as(u8, @intFromFloat(@round(fl * 255))),
                f32, f64 => fl,
                else => unreachable,
            };
        }
    };
}

/// Type to hold a Hex value of three bytes equivalent to an sRGB value. Effectively a convenience
/// wrapper for an Srgb(u8) represented as a u24, merging the red, green, and blue u8s together.
///
/// value: RRGGBB value as a 3-byte (24-bit) unsigned integer
pub const HexSrgb = struct {
    const Self = @This();

    value: u24,

    fn parseHexU8(r: u8, g: u8, b: u8) u24 {
        const byte0 = @as(u24, @intCast(r)) << 16;
        const byte1 = @as(u16, @intCast(g)) << 8;
        const byte2 = b;
        return byte0 | byte1 | byte2;
    }

    fn parseNibble(char: u8) u8 {
        return switch (char) {
            '0'...'9' => char - '0',
            'a'...'f' => char - 'a' + 10,
            'A'...'F' => char - 'A' + 10,
            else => @panic("Invalid hex digit"),
        };
    }

    fn parseByte(byte: []const u8) u8 {
        const nib_left = parseNibble(byte[0]) << 4;
        const nib_right = parseNibble(byte[1]);
        return nib_left | nib_right;
    }

    fn parseHexString(hex: anytype) SrgbError!u24 {
        const hex_str: []const u8 = hex;

        if (hex_str.len == 7 and hex_str[0] == '#') {
            return parseHexString(hex_str[1..]);
        }

        if (hex_str.len != 6) {
            return SrgbError.InvalidHexString;
        }

        const byte0: u24 = @as(u24, @intCast(parseByte(hex_str[0..2]))) << 16;
        const byte1: u24 = @as(u16, @intCast(parseByte(hex_str[2..4]))) << 8;
        const byte2: u24 = parseByte(hex_str[4..6]);

        return byte0 | byte1 | byte2;
    }

    pub fn initFromU8(r: u8, g: u8, b: u8) Self {
        return .{ .value = parseHexU8(r, g, b) };
    }

    pub fn initFromU24(hex: u24) Self {
        return .{ .value = hex };
    }

    pub fn initFromString(hex: []const u8) SrgbError!Self {
        const rgb = try parseHexString(hex);

        return .{ .value = rgb };
    }

    pub fn initFromSrgb(srgb: anytype) Self {
        const T = @TypeOf(srgb).Backing;
        if (T == u8) return .{ .value = parseHexU8(srgb.r, srgb.g, srgb.b) };

        const r = @as(u8, @intFromFloat(@round(srgb.r * 255.0)));
        const g = @as(u8, @intFromFloat(@round(srgb.g * 255.0)));
        const b = @as(u8, @intFromFloat(@round(srgb.b * 255.0)));
        return .{ .value = parseHexU8(r, g, b) };
    }

    pub fn toXyz(self: Self, comptime T: type) Xyz(T) {
        return self.toSrgb(T).toXyz();
    }

    pub fn fromXyz(xyz: anytype) Self {
        const T = @TypeOf(xyz).Backing;
        return initFromSrgb(Srgb(T).fromXyz(xyz));
    }

    pub inline fn toSrgb(self: Self, comptime T: type) Srgb(T) {
        const r: u8 = @as(u8, @intCast(self.value >> 16 & 0xFF));
        const g: u8 = @as(u8, @intCast(self.value >> 8 & 0xFF));
        const b: u8 = @as(u8, @intCast(self.value & 0xFF));

        if (T == u8) {
            return Srgb(u8).init(r, g, b);
        }

        return Srgb(T).init(
            @as(T, @floatFromInt(r)) / 255.0,
            @as(T, @floatFromInt(g)) / 255.0,
            @as(T, @floatFromInt(b)) / 255.0,
        );
    }
};

// ///////////////////////////////////////////////////////////////////////// //
// ///////////////////////////////   TESTS   /////////////////////////////// //
// ///////////////////////////////////////////////////////////////////////// //

// Tolerances are used for some comparisons to allow inexact approximation checks:
// * For u8, compared values should differ by no more than 1.
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
//
// There also exist situations where rounding/truncation during conversions will cause integer
// values to not be exactly equal.

// //////////////////////// //
// ////////  Srgb  //////// //
// //////////////////////// //
test "Srgb(u8) toLinear" {
    const tolerance: u8 = 1;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = LinearSrgb(u8).init(147, 32, 8);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = LinearSrgb(u8).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = LinearSrgb(u8).init(255, 255, 255);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = LinearSrgb(u8).init(2, 147, 7);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toLinear" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = LinearSrgb(f32).init(0.578, 0.127, 0.032);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = LinearSrgb(f32).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = LinearSrgb(f32).init(1, 1, 1);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = LinearSrgb(f32).init(0.008, 0.577, 0.026);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toLinear" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = LinearSrgb(f64).init(0.577580, 0.127438, 0.031896);
    var actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = LinearSrgb(f64).init(0, 0, 0);
    actual = srgb.toLinear();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = LinearSrgb(f64).init(1, 1, 1);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = LinearSrgb(f64).init(0.008023, 0.577580, 0.026241);
    actual = srgb.toLinear();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toXyz" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Xyz(f32).init(0.289, 0.216, 0.056);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Xyz(f32).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Xyz(f32).init(0.950, 1.000, 1.089);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Xyz(f32).init(0.214, 0.417, 0.093);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toXyz" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Xyz(f32).init(0.289, 0.216, 0.056);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Xyz(f32).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Xyz(f32).init(0.950, 1.000, 1.089);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Xyz(f32).init(0.214, 0.417, 0.093);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toXyz" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Xyz(f64).init(0.289550, 0.216274, 0.056667);
    var actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Xyz(f64).init(0, 0, 0);
    actual = srgb.toXyz();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Xyz(f64).init(0.950470, 1.000000, 1.088830);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Xyz(f64).init(0.214573, 0.416657, 0.093935);
    actual = srgb.toXyz();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toCmyk" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Cmyk(f32).init(0.000, 0.500, 0.750, 0.216);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Cmyk(f32).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Cmyk(f32).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Cmyk(f32).init(0.890, 0.000, 0.775, 0.216);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toCmyk" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Cmyk(f32).init(0.000, 0.500, 0.750, 0.216);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Cmyk(f32).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Cmyk(f32).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Cmyk(f32).init(0.890, 0.000, 0.775, 0.216);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toCmyk" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Cmyk(f64).init(0.000000, 0.500001, 0.750000, 0.215687);
    var actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Cmyk(f64).init(0, 0, 0, 1);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Cmyk(f64).init(0, 0, 0, 0);
    actual = srgb.toCmyk();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Cmyk(f64).init(0.890001, 0.000000, 0.775001, 0.215687);
    actual = srgb.toCmyk();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsi" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsi(f32).init(19.999, 0.571, 0.458);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsi(f32).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsi(f32).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsi(f32).init(127.753, 0.753, 0.349);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsi" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsi(f32).init(19.999, 0.571, 0.458);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsi(f32).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsi(f32).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsi(f32).init(127.736, 0.753, 0.349);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsi" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsi(f64).init(19.999966, 0.571429, 0.457516);
    var actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsi(f64).init(null, 0, 0);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsi(f64).init(null, 0, 1);
    actual = srgb.toHsi();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsi(f64).init(127.752805, 0.752810, 0.349019);
    actual = srgb.toHsi();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsl" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsl(f32).init(19.999, 0.600, 0.490);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsl(f32).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsl(f32).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsl(f32).init(127.753, 0.802, 0.435);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsl" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsl(f32).init(19.999, 0.600, 0.490);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsl(f32).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsl(f32).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsl(f32).init(127.736, 0.802, 0.435);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsl" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsl(f64).init(19.999966, 0.600000, 0.490196);
    var actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsl(f64).init(null, 0, 0);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsl(f64).init(null, 0, 1);
    actual = srgb.toHsl();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsl(f64).init(127.752805, 0.801803, 0.435294);
    actual = srgb.toHsl();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHsv" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hsv(f32).init(19.999, 0.750, 0.784);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hsv(f32).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hsv(f32).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hsv(f32).init(127.753, 0.890, 0.784);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHsv" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hsv(f32).init(19.999, 0.750, 0.784);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hsv(f32).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hsv(f32).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hsv(f32).init(127.736, 0.890, 0.784);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHsv" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hsv(f64).init(19.999966, 0.750000, 0.784313);
    var actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hsv(f64).init(null, 0, 0);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hsv(f64).init(null, 0, 1);
    actual = srgb.toHsv();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hsv(f64).init(127.752805, 0.890001, 0.784313);
    actual = srgb.toHsv();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// Converting from a u8 RGB value to float-only color-space implicitly casts RGB to f32
test "Srgb(u8) toHwb" {
    const tolerance = 0.002;

    var srgb = Srgb(u8).init(200, 100, 50);
    var expected = Hwb(f32).init(19.999, 0.196, 0.216);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(u8).init(0, 0, 0);
    expected = Hwb(f32).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(255, 255, 255);
    expected = Hwb(f32).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(u8).init(22, 200, 45);
    expected = Hwb(f32).init(127.753, 0.086, 0.216);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f32) toHwb" {
    const tolerance = 0.002;

    var srgb = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var expected = Hwb(f32).init(19.999, 0.196, 0.216);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f32).init(0, 0, 0);
    expected = Hwb(f32).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(1, 1, 1);
    expected = Hwb(f32).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    expected = Hwb(f32).init(127.736, 0.086, 0.216);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Srgb(f64) toHwb" {
    const tolerance = 0.000002;

    var srgb = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var expected = Hwb(f64).init(19.999966, 0.196078, 0.215687);
    var actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    srgb = Srgb(f64).init(0, 0, 0);
    expected = Hwb(f64).init(null, 0, 1);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(1, 1, 1);
    expected = Hwb(f64).init(null, 1, 0);
    actual = srgb.toHwb();
    try std.testing.expectEqual(expected, actual);

    srgb = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    expected = Hwb(f64).init(127.752805, 0.086274, 0.215687);
    actual = srgb.toHwb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// //////////////////////// //
// /////  LinearSrgb  ///// //
// //////////////////////// //
test "LinearSrgb(u8) toSrgb" {
    const tolerance: u8 = 1;

    var linear = LinearSrgb(u8).init(147, 32, 8);
    var expected = Srgb(u8).init(200, 100, 49);
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(u8).init(0, 0, 0);
    expected = Srgb(u8).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(u8).init(255, 255, 255);
    expected = Srgb(u8).init(255, 255, 255);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(u8).init(2, 147, 7);
    expected = Srgb(u8).init(22, 200, 45);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "LinearSrgb(f32) toSrgb" {
    const tolerance = 0.002;

    var linear = LinearSrgb(f32).init(0.578, 0.127, 0.032);
    var expected = Srgb(f32).init(0.784, 0.392, 0.196); // (200, 100, 50)
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f32).init(0, 0, 0);
    expected = Srgb(f32).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(f32).init(1, 1, 1);
    expected = Srgb(f32).init(1, 1, 1);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f32).init(0.008, 0.577, 0.026);
    expected = Srgb(f32).init(0.086, 0.784, 0.176); // (22, 200, 45)
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "LinearSrgb(f64) toSrgb" {
    const tolerance = 0.000002;

    var linear = LinearSrgb(f64).init(0.577580, 0.127438, 0.031896);
    var expected = Srgb(f64).init(0.784313, 0.392156, 0.196078); // (200, 100, 50)
    var actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f64).init(0, 0, 0);
    expected = Srgb(f64).init(0, 0, 0);
    actual = linear.toSrgb();
    try std.testing.expectEqual(expected, actual);

    linear = LinearSrgb(f64).init(1, 1, 1);
    expected = Srgb(f64).init(1, 1, 1);
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    linear = LinearSrgb(f64).init(0.008023, 0.577580, 0.026241);
    expected = Srgb(f64).init(0.086274, 0.784313, 0.176470); // (22, 200, 45)
    actual = linear.toSrgb();
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

// /////////////////////// //
// //////  HexSrgb  ////// //
// /////////////////////// //
test "HexSrgb initFromString" {
    var hex = try HexSrgb.initFromString("C86432");
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    const hex_str1 = "000000";
    hex = try HexSrgb.initFromString(hex_str1);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = try HexSrgb.initFromString("#ffffff");
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    const hex_str2 = "#16C82D";
    hex = try HexSrgb.initFromString(hex_str2);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);

    // Should error when given a string not in "#RRGGBB" or "RRGGBB" format
    const actual_err = HexSrgb.initFromString("0x123456");
    const expected_err = SrgbError.InvalidHexString;
    try std.testing.expectError(expected_err, actual_err);
}

test "HexSrgb initFromU8" {
    var hex = HexSrgb.initFromU8(200, 100, 50);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU8(0, 0, 0);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU8(255, 255, 255);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU8(22, 200, 45);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexSrgb initFromU24" {
    var hex = HexSrgb.initFromU24(0xc86432);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU24(0x000000);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU24(0xffffff);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    hex = HexSrgb.initFromU24(0x16c82d);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexSrgb initFromSrgb(u8)" {
    var srgb = Srgb(u8).init(200, 100, 50);
    var hex = HexSrgb.initFromSrgb(srgb);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(u8).init(0, 0, 0);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(u8).init(255, 255, 255);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(u8).init(22, 200, 45);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexSrgb initFromSrgb(f32)" {
    var srgb = Srgb(f32).init(0.784, 0.392, 0.196);
    var hex = HexSrgb.initFromSrgb(srgb);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f32).init(0, 0, 0);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f32).init(1, 1, 1);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f32).init(0.086, 0.784, 0.176);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexSrgb initFromSrgb(f64)" {
    var srgb = Srgb(f64).init(0.784, 0.392, 0.196);
    var hex = HexSrgb.initFromSrgb(srgb);
    var expected: u24 = 0xc86432;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f64).init(0, 0, 0);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x000000;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f64).init(1, 1, 1);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0xffffff;
    try std.testing.expectEqual(expected, hex.value);

    srgb = Srgb(f64).init(0.086, 0.784, 0.176);
    hex = HexSrgb.initFromSrgb(srgb);
    expected = 0x16c82d;
    try std.testing.expectEqual(expected, hex.value);
}

test "HexSrgb toSrgb(u8)" {
    var hex = HexSrgb.initFromU24(0xc86432);
    var srgb = hex.toSrgb(u8);
    var expected = Srgb(u8).init(200, 100, 50);
    try std.testing.expectEqual(expected, srgb);

    hex = HexSrgb.initFromU24(0x000000);
    srgb = hex.toSrgb(u8);
    expected = Srgb(u8).init(0, 0, 0);
    try std.testing.expectEqual(expected, srgb);

    hex = HexSrgb.initFromU24(0xffffff);
    srgb = hex.toSrgb(u8);
    expected = Srgb(u8).init(255, 255, 255);
    try std.testing.expectEqual(expected, srgb);

    hex = HexSrgb.initFromU24(0x16c82d);
    srgb = hex.toSrgb(u8);
    expected = Srgb(u8).init(22, 200, 45);
    try std.testing.expectEqual(expected, srgb);
}

test "HexSrgb toSrgb(f32)" {
    const tolerance = 0.002;

    var hex = HexSrgb.initFromU24(0xc86432);
    var srgb = hex.toSrgb(f32);
    var expected = Srgb(f32).init(0.784, 0.392, 0.196);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0x000000);
    srgb = hex.toSrgb(f32);
    expected = Srgb(f32).init(0, 0, 0);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0xffffff);
    srgb = hex.toSrgb(f32);
    expected = Srgb(f32).init(1, 1, 1);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0x16c82d);
    srgb = hex.toSrgb(f32);
    expected = Srgb(f32).init(0.086, 0.784, 0.176);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);
}

test "HexSrgb toSrgb(f64)" {
    const tolerance = 0.000002;

    var hex = HexSrgb.initFromU24(0xc86432);
    var srgb = hex.toSrgb(f64);
    var expected = Srgb(f64).init(0.784314, 0.392157, 0.196078);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0x000000);
    srgb = hex.toSrgb(f64);
    expected = Srgb(f64).init(0, 0, 0);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0xffffff);
    srgb = hex.toSrgb(f64);
    expected = Srgb(f64).init(1, 1, 1);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);

    hex = HexSrgb.initFromU24(0x16c82d);
    srgb = hex.toSrgb(f64);
    expected = Srgb(f64).init(0.086275, 0.784314, 0.176471);
    try validation.expectColorsApproxEqAbs(expected, srgb, tolerance);
}
