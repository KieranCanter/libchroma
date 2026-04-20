/// XYZ tristimulus values for a reference white under a given illuminant/observer.
pub const WhitePoint = struct {
    x: f64,
    y: f64,
    z: f64,
};

/// D65, 2° observer. Used by sRGB, Display P3, Rec. 2020, and CSS Color Level 5.
pub const d65 = WhitePoint{
    .x = 0.95047,
    .y = 1.0,
    .z = 1.08883,
};
