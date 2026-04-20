// Gamut mapping via OKLCH chroma reduction (CSS Color Level 5).
// https://www.w3.org/TR/css-color-5/

const std = @import("std");
const lib = @import("lib.zig");

const Oklab = @import("color/lab/oklab.zig").Oklab;
const Oklch = @import("color/lch/oklch.zig").Oklch;

const JND = 0.02;
const EPSILON = 0.0001;

fn deltaEOK(comptime T: type, a: Oklab(T), b: Oklab(T)) T {
    const dl = @as(T, a.l) - @as(T, b.l);
    const da = @as(T, a.a) - @as(T, b.a);
    const db = @as(T, a.b) - @as(T, b.b);
    return @sqrt(dl * dl + da * da + db * db);
}

/// Map any color into the gamut of Dest using OKLCH chroma reduction.
pub fn gamutMap(src: anytype, comptime Dest: type) Dest {
    const T = Dest.Backing;
    const jnd: T = JND;
    const epsilon: T = EPSILON;

    // Convert source to OkLCh
    const oklch_raw = lib.convert(src, Oklch(T));

    // If L >= 1, return white; if L <= 0, return black
    if (oklch_raw.l >= 1.0) return Dest.init(1, 1, 1);
    if (oklch_raw.l <= 0.0) return Dest.init(0, 0, 0);

    var current = oklch_raw;

    // If already in gamut, just convert directly
    const direct = lib.convert(current, Dest);
    if (direct.isInGamut()) return direct;

    // Binary search on chroma
    var min: T = 0;
    var max: T = current.c;
    var min_inGamut = true;

    while (max - min > epsilon) {
        const chroma = (min + max) / 2;
        current.c = chroma;

        if (min_inGamut and lib.convert(current, Dest).isInGamut()) {
            min = chroma;
            continue;
        }

        const clipped = lib.convert(current, Dest).clamp();
        const e = deltaEOK(T, lib.convert(current, Oklab(T)), lib.convert(clipped, Oklab(T)));

        if (e < jnd) {
            if (jnd - e < epsilon) return clipped;
            min_inGamut = false;
            min = chroma;
        } else {
            max = chroma;
        }
    }

    return lib.convert(current, Dest).clamp();
}

// Tests

const std_testing = std.testing;
const Srgb = @import("color/rgb/srgb.zig").Srgb;
const LinearSrgb = @import("color/rgb/srgb.zig").LinearSrgb;
const DisplayP3 = @import("color/rgb/display_p3.zig").DisplayP3;

test "P3 green gamut mapped to sRGB is in gamut" {
    const p3_green = DisplayP3(f32).init(0, 1, 0);
    const mapped = gamutMap(p3_green, Srgb(f32));
    try std_testing.expect(mapped.isInGamut());
}

test "P3 green converted to sRGB is out of gamut" {
    const p3_green = DisplayP3(f32).init(0, 1, 0);
    const converted = lib.convert(p3_green, Srgb(f32));
    try std_testing.expect(!converted.isInGamut());
}

test "gamutMap preserves in-gamut colors" {
    const srgb_red = Srgb(f32).init(1, 0, 0);
    const mapped = gamutMap(srgb_red, Srgb(f32));
    const tol: f32 = 0.002;
    try std_testing.expectApproxEqAbs(@as(f32, 1), mapped.r, tol);
    try std_testing.expectApproxEqAbs(@as(f32, 0), mapped.g, tol);
    try std_testing.expectApproxEqAbs(@as(f32, 0), mapped.b, tol);
}

test "gamutMap white and black" {
    const tol2: f32 = 0.002;

    // Very high lightness, high chroma, should map to white
    const white = gamutMap(Srgb(f32).init(1, 1, 1), Srgb(f32));
    try std_testing.expectApproxEqAbs(@as(f32, 1), white.r, tol2);
    try std_testing.expectApproxEqAbs(@as(f32, 1), white.g, tol2);
    try std_testing.expectApproxEqAbs(@as(f32, 1), white.b, tol2);

    // Black
    const black = gamutMap(Srgb(f32).init(0, 0, 0), Srgb(f32));
    try std_testing.expectApproxEqAbs(@as(f32, 0), black.r, tol2);
    try std_testing.expectApproxEqAbs(@as(f32, 0), black.g, tol2);
    try std_testing.expectApproxEqAbs(@as(f32, 0), black.b, tol2);
}

test "gamutMap P3 to sRGB reduces chroma" {
    // P3 primary red is out of sRGB gamut
    const p3_red = DisplayP3(f32).init(1, 0, 0);
    const mapped = gamutMap(p3_red, Srgb(f32));
    try std_testing.expect(mapped.isInGamut());
    // Should still be reddish (r > g, r > b)
    try std_testing.expect(mapped.r > mapped.g);
    try std_testing.expect(mapped.r > mapped.b);
}

test "clamp produces in-gamut result" {
    const out = Srgb(f32).init(-0.5, 1.2, 0.5);
    const clamped = out.clamp();
    try std_testing.expect(clamped.isInGamut());
    try std_testing.expectEqual(@as(f32, 0), clamped.r);
    try std_testing.expectEqual(@as(f32, 1), clamped.g);
    try std_testing.expectEqual(@as(f32, 0.5), clamped.b);
}

test "isInGamut detects out-of-range" {
    try std_testing.expect(!Srgb(f32).init(-0.1, 0.5, 0.5).isInGamut());
    try std_testing.expect(!Srgb(f32).init(0.5, 1.1, 0.5).isInGamut());
    try std_testing.expect(Srgb(f32).init(0, 0.5, 1).isInGamut());
}

test "deltaEOK identical colors is zero" {
    const a = Oklab(f32){ .l = 0.5, .a = 0.1, .b = -0.1 };
    try std_testing.expectApproxEqAbs(@as(f32, 0), deltaEOK(f32, a, a), 0.0001);
}

test "deltaEOK known distance" {
    const a = Oklab(f32){ .l = 0.5, .a = 0.0, .b = 0.0 };
    const b = Oklab(f32){ .l = 0.6, .a = 0.0, .b = 0.0 };
    try std_testing.expectApproxEqAbs(@as(f32, 0.1), deltaEOK(f32, a, b), 0.0001);
}
