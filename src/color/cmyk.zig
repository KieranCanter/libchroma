const std = @import("std");
const validation = @import("../validation.zig");
const chroma_testing = @import("../testing.zig");
const fmt = @import("../fmt.zig");

const Srgb = @import("rgb/srgb.zig").Srgb;
const CieXyz = @import("xyz/cie_xyz.zig").CieXyz;
const CmykError = error{OutOfRange};

/// CMYK color.
/// `c`: cyan in [0, 1]
/// `m`: magenta in [0, 1]
/// `y`: yellow in [0, 1]
/// `k`: black in [0, 1]
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

        pub fn formatter(self: Self, style: fmt.FormatStyle) fmt.TypeFormat(Self) {
            return fmt.TypeFormat(Self).init(self, style);
        }

        pub fn format(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            try writer.print("{d}, {d}, {d}, {d}", .{ self.c, self.m, self.y, self.k });
        }

        pub fn formatPretty(self: Self, writer: *std.Io.Writer) std.Io.Writer.Error!void {
            const c_percent = self.c * 100;
            const m_percent = self.m * 100;
            const y_percent = self.y * 100;
            const k_percent = self.k * 100;
            try writer.print("Cmyk({s})({d}%, {d}%, {d}%, {d}%)", .{ @typeName(T), c_percent, m_percent, y_percent, k_percent });
        }

        // Gray Component Replacement
        pub fn gcr(self: *Self, strength: T) CmykError!void {
            if (strength < 0 or strength > 1) {
                return CmykError.OutOfRange;
            }

            const gray = @min(self.c, self.m, self.y) * strength;

            self.c -= gray;
            self.m -= gray;
            self.y -= gray;
            self.k += gray;
        }

        // Under Color Removal
        pub fn ucr(self: *Self) void {
            return self.gcr(1) catch unreachable;
        }

        // Under Color Addition
        pub fn uca(self: *Self, strength: T) CmykError!void {
            if (strength < 0 or strength > 1) {
                return CmykError.OutOfRange;
            }

            const removed = self.k * strength;

            self.c += removed;
            self.m += removed;
            self.y += removed;
            self.k -= removed;
        }

        pub fn toCieXyz(self: Self) CieXyz(T) {
            return self.toSrgb().toCieXyz();
        }

        pub fn fromCieXyz(xyz: anytype) Self {
            return Srgb(T).fromCieXyz(xyz).toCmyk();
        }

        // Formula for CMYK -> sRGB conversion:
        // https://www.101computing.net/cmyk-to-rgb-conversion-algorithm/
        pub fn toSrgb(self: Self) Srgb(T) {
            const r = (1 - self.c) * (1 - self.k);
            const g = (1 - self.m) * (1 - self.k);
            const b = (1 - self.y) * (1 - self.k);

            return Srgb(T).init(r, g, b);
        }
    };
}

// Tests
// Tolerances: 0.002 (f32) / 0.000002 (f64) to account for rounding without
// manually truncating decimal places.

const tol = 0.002;

test "Cmyk(f32) toSrgb" {
    const c = Cmyk(f32).init(0.0, 0.5, 0.75, 0.2).toSrgb();
    try std.testing.expectApproxEqAbs(@as(f32, 0.800), c.r, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.400), c.g, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.200), c.b, tol);

    // Full black (K=1)
    const black = Cmyk(f32).init(0, 0, 0, 1).toSrgb();
    try std.testing.expectEqual(Srgb(f32).init(0, 0, 0), black);
}

test "Cmyk(f32) <-> XYZ round-trip" {
    const original = Cmyk(f32).init(0.0, 0.5, 0.75, 0.2);
    const result = Cmyk(f32).fromCieXyz(original.toCieXyz());
    try chroma_testing.expectColorsApproxEqAbs(original, result, tol);
}

test "Cmyk gcr" {
    var c = Cmyk(f32).init(0.4, 0.3, 0.5, 0.1);
    try c.gcr(1.0);
    // gray = min(0.4, 0.3, 0.5) * 1.0 = 0.3
    try std.testing.expectApproxEqAbs(@as(f32, 0.1), c.c, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.0), c.m, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c.y, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), c.k, tol);
}

test "Cmyk uca" {
    var c = Cmyk(f32).init(0.1, 0.0, 0.2, 0.4);
    try c.uca(0.5);
    // removed = 0.4 * 0.5 = 0.2
    try std.testing.expectApproxEqAbs(@as(f32, 0.3), c.c, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c.m, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.4), c.y, tol);
    try std.testing.expectApproxEqAbs(@as(f32, 0.2), c.k, tol);
}

test "Cmyk gcr error on invalid strength" {
    var c = Cmyk(f32).init(0.5, 0.3, 0.2, 0.0);
    try std.testing.expectError(CmykError.OutOfRange, c.gcr(-0.1));
    try std.testing.expectError(CmykError.OutOfRange, c.gcr(1.1));
}

test "Cmyk uca error on invalid strength" {
    var c = Cmyk(f32).init(0.5, 0.3, 0.2, 0.4);
    try std.testing.expectError(CmykError.OutOfRange, c.uca(-0.1));
    try std.testing.expectError(CmykError.OutOfRange, c.uca(1.1));
}
