const std = @import("std");
const validation = @import("validation.zig");

const cmyk = @import("color_space/cmyk.zig");
const hsi = @import("color_space/hsi.zig");
const hsl = @import("color_space/hsl.zig");
const hsv = @import("color_space/hsv.zig");
const hwb = @import("color_space/hwb.zig");
const srgb = @import("color_space/srgb.zig");
const xyz = @import("color_space/xyz.zig");
const yxy = @import("color_space/yxy.zig");

// Color space exports
pub const Cmyk = cmyk.Cmyk;
pub const Hex = srgb.HexSrgb;
pub const Hsi = hsi.Hsi;
pub const Hsl = hsl.Hsl;
pub const Hsv = hsv.Hsv;
pub const Hwb = hwb.Hwb;
pub const LinearSrgb = srgb.LinearSrgb;
pub const Srgb = srgb.Srgb;
pub const Xyz = xyz.Xyz;
pub const Yxy = yxy.Yxy;

pub const ChromaError = srgb.SrgbError;

// Universal conversion
pub fn convert(src: anytype, comptime Dest: type) Dest {
    const Src = @TypeOf(src);
    validation.assertColorInterface(Src);
    validation.assertColorInterface(Dest);

    // Short circuit the conversion if the type has a function named "to<Dest>()"
    const toDest_fn_name = "to" ++ @typeName(Dest);
    if (@hasDecl(Src, toDest_fn_name)) {
        return @call(.auto, @field(Src, toDest_fn_name), .{src});
    }

    // Otherwise, go through canonical color space XYZ
    // The canonical color space should implement conversion functions to every other color space
    return src.fromXyz(src.toXyz());
}

pub inline fn cast(comptime src: anytype, comptime Dest: type) Dest {
    const Src = @TypeOf(src);
    validation.assertColorInterface(Src);
    return src.cast(Dest);
}

test {
    std.testing.refAllDeclsRecursive(@This());
}
