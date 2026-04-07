/// Standard illuminant white point reference values for CIE color spaces.
/// Each white point defines the XYZ tristimulus values of the reference white
/// under a specific illuminant and observer combination.
pub const WhitePoint = struct {
    x: f64,
    y: f64,
    z: f64,
};

/// CIE Standard Illuminant D65, 2° observer.
/// The standard daylight illuminant used by sRGB, Display P3, Rec. 2020,
/// and CSS Color Level 5 color spaces.
pub const d65 = WhitePoint{
    .x = 0.95047,
    .y = 1.0,
    .z = 1.08883,
};
