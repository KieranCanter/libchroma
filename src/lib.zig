// color.js (javascript) and coloraide (python) used as references:
// https://github.com/color-js/color.js/tree/main
// https://github.com/facelessuser/coloraide

const std = @import("std");
const validation = @import("validation.zig");

const cmyk = @import("color_space/cmyk.zig");
const hsi = @import("color_space/hsi.zig");
const hsl = @import("color_space/hsl.zig");
const hsv = @import("color_space/hsv.zig");
const hwb = @import("color_space/hwb.zig");
const rgb = @import("color_space/rgb.zig");
const xyz = @import("color_space/xyz.zig");
const yxy = @import("color_space/yxy.zig");

// Color space exports
pub const Cmyk = cmyk.Cmyk;
pub const Hsi = hsi.Hsi;
pub const Hsl = hsl.Hsl;
pub const Hsv = hsv.Hsv;
pub const Hwb = hwb.Hwb;
pub const Xyz = xyz.Xyz;
pub const Yxy = yxy.Yxy;

// RGB Color Spaces
pub const HexRgb = rgb.HexRgb;
pub const Srgb = rgb.srgb.Srgb;
pub const LinearSrgb = rgb.srgb.LinearSrgb;
pub const P3 = rgb.p3.P3;
pub const LinearP3 = rgb.p3.LinearP3;
pub const Rec2020 = rgb.rec2020.Rec2020;
pub const Rec2020Scene = rgb.rec2020.Rec2020Scene;
pub const LinearRec2020 = rgb.rec2020.LinearRec2020;

pub const RgbError = rgb.RgbError;
pub const ChromaError = error{OutOfRange};

// Universal conversion
pub fn convert(src: anytype, comptime Dest: type) Dest {
    const Src = @TypeOf(src);
    validation.assertColorInterface(Src);
    validation.assertColorInterface(Dest);

    // Short circuit the conversion if the type has a function named "to<Dest>()"
    const toDest_fn_name = "to" ++ @typeName(Dest);
    if (std.meta.hasMethod(Src, toDest_fn_name)) {
        return @call(.auto, @field(Src, toDest_fn_name), .{src});
    }

    // Otherwise, go through canonical color space XYZ.
    // By the Color interface contract, every color space should implement a `toXyz()` function and
    // a `fromXyz()` function.
    return src.fromXyz(src.toXyz());
}

// In testing, tolerances are used for some comparisons to allow inexact approximation checks:
// * For u8, compared values should differ by no more than 1.
// * For f32, when truncated to 3 decimal places, compared values should differ by no more than
// 0.001.
// * For f64, when truncated to 6 decimal places, compared values should differ by no more than
// 0.000001.
//
// To prevent having to manually truncate all values to the specified number of decimal places,
// 0.002 and 0.000002 are used as tolerances. For example, if we have an expected value of 0.392156
// and an actual value of 0.39215732995152763, this would technically fail with a 0.000001
// tolerance because at the sixth decimal place, there is about a 0.0000013 difference, but if we
// truncated the actual value to six decimal places, it would be 0.392157, which only has a
// 0.000001 difference with our expected value.
//
// There also exist situations where rounding/truncation during conversions will cause integer
// values to not be exactly equal.
test {
    std.testing.refAllDeclsRecursive(@This());
}
