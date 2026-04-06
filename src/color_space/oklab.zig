const std = @import("std");
const assertFloatType = @import("../validation.zig").assertFloatType;
const color_formatter = @import("../color_formatter.zig");

const LinearSrgb = @import("rgb/srgb.zig").LinearSrgb;
const Oklch = @import("oklch.zig").Oklch;
const Xyz = @import("xyz.zig").Xyz;

// OKLab matrices from Björn Ottosson's specification:
// https://bottosson.github.io/posts/oklab/

// M1: linear sRGB -> LMS (approximate cone responses)
const M1: [3][3]f64 = .{
    .{ 0.4122214708, 0.5363325363, 0.0514459929 },
    .{ 0.2119034982, 0.6806995451, 0.1073969566 },
    .{ 0.0883024619, 0.2817188376, 0.6299787005 },
};

// M2: LMS (cube-rooted) -> OKLab
const M2: [3][3]f64 = .{
    .{ 0.2104542553, 0.7936177850, -0.0040720468 },
    .{ 1.9779984951, -2.4285922050, 0.4505937099 },
    .{ 0.0259040371, 0.7827717662, -0.8086757660 },
};

// M1 inverse: LMS -> linear sRGB
const M1_INV: [3][3]f64 = .{
    .{ 4.0767416621, -3.3077115913, 0.2309699292 },
    .{ -1.2684380046, 2.6097574011, -0.3413193965 },
    .{ -0.0041960863, -0.7034186147, 1.7076147010 },
};

// M2 inverse: OKLab -> LMS (cube-rooted)
const M2_INV: [3][3]f64 = .{
    .{ 1.0000000000, 0.3963377774, 0.2158037573 },
    .{ 1.0000000000, -0.1055613458, -0.0638541728 },
    .{ 1.0000000000, -0.0894841775, -1.2914855480 },
};

/// Type to hold an OKLab value — a perceptually uniform color space by Björn Ottosson.
///
/// l: perceived lightness in [0, 1]
/// a: green–red axis, roughly [-0.4, 0.4]
/// b: blue–yellow axis, roughly [-0.4, 0.4]
pub fn Oklab(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        l: T,
        a: T,
        b: T,

        pub fn init(l: T, a: T, b: T) Self {
            return .{ .l = l, .a = a, .b = b };
        }

        pub fn formatter(self: Self, style: color_formatter.ColorFormatStyle) color_formatter.ColorFormatter(Self) {
            return color_formatter.ColorFormatter(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d}, {d}, {d}", .{ self.l, self.a, self.b });
        }

        // OKLab -> XYZ via linear sRGB
        pub fn toXyz(self: Self) Xyz(T) {
            return self.toLinearSrgb().toXyz();
        }

        // XYZ -> OKLab via linear sRGB
        pub fn fromXyz(xyz: Xyz(T)) Self {
            return Self.fromLinearSrgb(LinearSrgb(T).fromXyz(xyz));
        }

        // OKLab -> linear sRGB (M2_INV -> cube -> M1_INV)
        pub fn toLinearSrgb(self: Self) LinearSrgb(T) {
            const l_: T = @floatCast(M2_INV[0][0] * @as(f64, self.l) + M2_INV[0][1] * @as(f64, self.a) + M2_INV[0][2] * @as(f64, self.b));
            const m_: T = @floatCast(M2_INV[1][0] * @as(f64, self.l) + M2_INV[1][1] * @as(f64, self.a) + M2_INV[1][2] * @as(f64, self.b));
            const s_: T = @floatCast(M2_INV[2][0] * @as(f64, self.l) + M2_INV[2][1] * @as(f64, self.a) + M2_INV[2][2] * @as(f64, self.b));

            const l3 = l_ * l_ * l_;
            const m3 = m_ * m_ * m_;
            const s3 = s_ * s_ * s_;

            return LinearSrgb(T).init(
                @floatCast(M1_INV[0][0] * @as(f64, l3) + M1_INV[0][1] * @as(f64, m3) + M1_INV[0][2] * @as(f64, s3)),
                @floatCast(M1_INV[1][0] * @as(f64, l3) + M1_INV[1][1] * @as(f64, m3) + M1_INV[1][2] * @as(f64, s3)),
                @floatCast(M1_INV[2][0] * @as(f64, l3) + M1_INV[2][1] * @as(f64, m3) + M1_INV[2][2] * @as(f64, s3)),
            );
        }

        // linear sRGB -> OKLab (M1 -> cbrt -> M2)
        pub fn fromLinearSrgb(lrgb: LinearSrgb(T)) Self {
            const l_ = std.math.cbrt(@as(f64, M1[0][0]) * @as(f64, lrgb.r) + @as(f64, M1[0][1]) * @as(f64, lrgb.g) + @as(f64, M1[0][2]) * @as(f64, lrgb.b));
            const m_ = std.math.cbrt(@as(f64, M1[1][0]) * @as(f64, lrgb.r) + @as(f64, M1[1][1]) * @as(f64, lrgb.g) + @as(f64, M1[1][2]) * @as(f64, lrgb.b));
            const s_ = std.math.cbrt(@as(f64, M1[2][0]) * @as(f64, lrgb.r) + @as(f64, M1[2][1]) * @as(f64, lrgb.g) + @as(f64, M1[2][2]) * @as(f64, lrgb.b));

            return Self.init(
                @floatCast(M2[0][0] * l_ + M2[0][1] * m_ + M2[0][2] * s_),
                @floatCast(M2[1][0] * l_ + M2[1][1] * m_ + M2[1][2] * s_),
                @floatCast(M2[2][0] * l_ + M2[2][1] * m_ + M2[2][2] * s_),
            );
        }

        // OKLab -> OKLCH (cartesian to polar)
        pub fn toOklch(self: Self) Oklch(T) {
            const c = @sqrt(self.a * self.a + self.b * self.b);
            if (c < 1e-10) {
                return Oklch(T).init(self.l, 0, null);
            }
            var h = std.math.atan2(self.b, self.a) * (180.0 / std.math.pi);
            if (h < 0) h += 360.0;
            return Oklch(T).init(self.l, c, h);
        }
    };
}

// ============================================================================
// TESTS
// ============================================================================

const Srgb = @import("rgb/srgb.zig").Srgb;
const validation = @import("../validation.zig");

test "Oklab(f32) fromLinearSrgb" {
    const tolerance = 0.002;

    // White
    var lrgb = LinearSrgb(f32).init(1, 1, 1);
    var expected = Oklab(f32).init(1.0, 0.0, 0.0);
    var actual = Oklab(f32).fromLinearSrgb(lrgb);
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);

    // Black
    lrgb = LinearSrgb(f32).init(0, 0, 0);
    expected = Oklab(f32).init(0.0, 0.0, 0.0);
    actual = Oklab(f32).fromLinearSrgb(lrgb);
    try std.testing.expectEqual(expected, actual);

    // Red (sRGB 1,0,0 -> linear 1,0,0)
    lrgb = LinearSrgb(f32).init(1, 0, 0);
    expected = Oklab(f32).init(0.628, 0.225, 0.126);
    actual = Oklab(f32).fromLinearSrgb(lrgb);
    try validation.expectColorsApproxEqAbs(expected, actual, tolerance);
}

test "Oklab(f32) toLinearSrgb round-trip" {
    const tolerance = 0.002;

    const original = LinearSrgb(f32).init(0.578, 0.127, 0.032);
    const oklab = Oklab(f32).fromLinearSrgb(original);
    const result = oklab.toLinearSrgb();
    try validation.expectColorsApproxEqAbs(original, result, tolerance);
}

test "Oklab(f64) toLinearSrgb round-trip" {
    const tolerance = 0.000002;

    const original = LinearSrgb(f64).init(0.577580, 0.127438, 0.031896);
    const oklab = Oklab(f64).fromLinearSrgb(original);
    const result = oklab.toLinearSrgb();
    try validation.expectColorsApproxEqAbs(original, result, tolerance);
}

test "Oklab(f32) toOklch" {
    const tolerance = 0.002;

    // Achromatic
    var oklab = Oklab(f32).init(0.5, 0.0, 0.0);
    var oklch = oklab.toOklch();
    try std.testing.expectApproxEqAbs(@as(f32, 0.5), oklch.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), oklch.c, tolerance);
    try std.testing.expectEqual(@as(?f32, null), oklch.h);

    // Chromatic (red-ish)
    oklab = Oklab(f32).init(0.628, 0.225, 0.126);
    oklch = oklab.toOklch();
    try std.testing.expectApproxEqAbs(@as(f32, 0.628), oklch.l, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 0.258), oklch.c, tolerance);
    try std.testing.expectApproxEqAbs(@as(f32, 29.249), oklch.h.?, tolerance);
}
