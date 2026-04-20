/// XYZ tristimulus values for a reference white under a given illuminant.
x: f64,
y: f64,
z: f64,

const Self = @This();

/// CIE standard illuminant D65 (daylight, 6504K) with 2-degree observer.
/// Used by sRGB, Display P3, Rec. 2020, and CIE L*a*b*.
pub const d65: Self = .{
    .x = 0.95047,
    .y = 1.0,
    .z = 1.08883,
};

/// CIE standard illuminant D50 (horizon light, 5003K) with 2-degree observer.
/// Used by ICC profiles and ProPhoto RGB.
pub const d50: Self = .{
    .x = 0.96422,
    .y = 1.0,
    .z = 0.82521,
};
