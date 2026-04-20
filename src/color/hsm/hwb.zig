const std = @import("std");
const assertFloatType = @import("../../validation.zig").assertFloatType;
const validation = @import("../../validation.zig");
const chroma_testing = @import("../../testing.zig");
const fmt = @import("../../fmt.zig");

const Hsv = @import("hsv.zig").Hsv;
const Srgb = @import("../rgb/srgb.zig").Srgb;
const CieXyz = @import("../xyz/cie_xyz.zig").CieXyz;

/// HWB color.
/// `h`: hue in [0, 360] or `null` when achromatic
/// `w`: whiteness in [0, 1]
/// `b`: blackness in [0, 1]
pub fn Hwb(comptime T: type) type {
    assertFloatType(T);

    return struct {
        const Self = @This();
        pub const Backing = T;

        h: ?T,
        w: T,
        b: T,

        pub fn init(h: ?T, w: T, b: T) Self {
            return .{ .h = h, .w = w, .b = b };
        }

        pub fn formatter(self: Self, style: fmt.FormatStyle) fmt.TypeFormat(Self) {
            return fmt.TypeFormat(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{?d}, {d}, {d}", .{ self.h, self.w, self.b });
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self.toSrgb().toCieXyz();
        }

        pub fn fromCieXyz(xyz: anytype) Self {
            return Srgb(T).fromCieXyz(xyz).toHwb();
        }

        // Formula for HWB -> sRGB conversion:
        // https://alvyray.com/Papers/CG/HWB_JGTv208.pdf
        pub fn toSrgb(self: Self) Srgb(T) {
            if (self.h == null) {
                const gray = 1.0 - self.b;
                return Srgb(T).init(gray, gray, gray);
            }

            const h = self.h.?;
            const v = 1.0 - self.b;
            const hprime = h / 60.0;
            const sector: u8 = @intFromFloat(@floor(hprime));
            var f = hprime - @floor(hprime);

            if (sector & 1 != 0) {
                f = 1 - f;
            }

            const n = self.w + f * (v - self.w);

            return switch (sector) {
                0, 6 => Srgb(T).init(v, n, self.w),
                1 => Srgb(T).init(n, v, self.w),
                2 => Srgb(T).init(self.w, v, n),
                3 => Srgb(T).init(self.w, n, v),
                4 => Srgb(T).init(n, self.w, v),
                5 => Srgb(T).init(v, self.w, n),
                else => unreachable,
            };
        }

        // Formula for HWB -> HSV conversion:
        // https://en.wikipedia.org/wiki/HWB_color_model
        pub fn toHsv(self: Self) Hsv(T) {
            const s = 1 - (self.w / (1 - self.b));
            const v = 1 - self.b;
            return Hsv(T).init(self.h, s, v);
        }
    };
}

// Tests

const tol = 0.002;

test "Hwb(f32) toSrgb" {
    const c = Hwb(f32).init(20.0, 0.2, 0.2).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), c.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.400), c.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), c.b, tol);

    // Achromatic (null hue) -> gray based on blackness
    const gray = Hwb(f32).init(null, 0.3, 0.3).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.7), gray.r, tol);
}

test "Hwb(f32) <-> XYZ round-trip" {
    const original = Hwb(f32).init(20.0, 0.2, 0.2);
    const result = Hwb(f32).fromCieXyz(original.toCieXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "Hwb(f32) toHsv" {
    const hsv = Hwb(f32).init(20.0, 0.2, 0.2).toHsv();
    try std.testing.expectApproxEqAbs(@as(f32, 20.0), hsv.h.?, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.750), hsv.s, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), hsv.v, tol);
}
