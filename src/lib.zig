const std = @import("std");

// C ABI exports (pull in so export fn symbols are included in the library)
comptime {
    _ = @import("c/chroma.zig");
}

// Namespaces
// Access the full module: chroma.rgb, chroma.gamut, chroma.alpha, etc.

pub const rgb = @import("color_space/rgb.zig");
pub const cmyk = @import("color_space/cmyk.zig");
pub const hsi = @import("color_space/hsi.zig");
pub const hsl = @import("color_space/hsl.zig");
pub const hsv = @import("color_space/hsv.zig");
pub const hwb = @import("color_space/hwb.zig");
pub const lab = @import("color_space/lab.zig");
pub const lch = @import("color_space/lch.zig");
pub const oklab = @import("color_space/oklab.zig");
pub const oklch = @import("color_space/oklch.zig");
pub const xyz = @import("color_space/xyz.zig");
pub const yxy = @import("color_space/yxy.zig");
pub const alpha = @import("alpha.zig");
pub const gamut = @import("gamut.zig");

// Convenience shortcuts for major types like Colors and Alpha

// RGB
pub const Srgb = rgb.srgb.Srgb;
pub const LinearSrgb = rgb.srgb.LinearSrgb;
pub const DisplayP3 = rgb.display_p3.DisplayP3;
pub const LinearDisplayP3 = rgb.display_p3.LinearDisplayP3;
pub const Rec2020 = rgb.rec2020.Rec2020;
pub const Rec2020Scene = rgb.rec2020.Rec2020Scene;
pub const LinearRec2020 = rgb.rec2020.LinearRec2020;

// Others
pub const Cmyk = cmyk.Cmyk;
pub const Hsi = hsi.Hsi;
pub const Hsl = hsl.Hsl;
pub const Hsv = hsv.Hsv;
pub const Hwb = hwb.Hwb;
pub const Lab = lab.Lab;
pub const Lch = lch.Lch;
pub const Oklab = oklab.Oklab;
pub const Oklch = oklch.Oklch;
pub const Xyz = xyz.Xyz;
pub const Yxy = yxy.Yxy;

// Alpha
pub const Alpha = alpha.Alpha;

// Expose Color interface contract
const validation = @import("validation.zig");
pub const assertColorInterface = validation.assertColorInterface;

// Universal conversion
pub fn convert(src: anytype, comptime Dest: type) Dest {
    const Src = @TypeOf(src);
    assertColorInterface(Src);
    assertColorInterface(Dest);

    // anonymous function for converting after you ensure the src and dest are Color types and not wrapper types (e.g.
    // Alpha);
    const convertInner = struct {
        inline fn func(src_color: anytype, comptime DestColor: type) DestColor {
            const SrcColor = @TypeOf(src_color);
            const destName = comptime blk: {
                var name = validation.colorSpaceName(DestColor);
                const maybe_open_paren = std.mem.indexOfScalar(u8, name, '(');
                if (maybe_open_paren) |open_paren| {
                    name = name[0..open_paren];
                }
                break :blk name;
            };
            const toDest_fn_name = "to" ++ destName;
            if (std.meta.hasMethod(SrcColor, toDest_fn_name)) {
                return @call(.auto, @field(SrcColor, toDest_fn_name), .{src_color});
            }

            const srcName = comptime blk: {
                var name = validation.colorSpaceName(SrcColor);
                const maybe_open_paren = std.mem.indexOfScalar(u8, name, '(');
                if (maybe_open_paren) |open_paren| {
                    name = name[0..open_paren];
                }
                break :blk name;
            };
            const fromSrc_fn_name = "from" ++ srcName;
            if (std.meta.hasMethod(DestColor, fromSrc_fn_name)) {
                return @call(.auto, @field(DestColor, fromSrc_fn_name), .{src_color});
            }

            return DestColor.fromXyz(src_color.toXyz());
        }
    }.func;

    const src_is_alpha = alpha.isAlpha(Src);
    const dest_is_alpha = alpha.isAlpha(Dest);

    if (src_is_alpha and dest_is_alpha) {
        return Dest.init(
            convertInner(src.color, Dest.Inner),
            src.alpha,
        );
    }

    if (src_is_alpha) {
        return convertInner(src.color, Dest);
    }

    if (dest_is_alpha) {
        return Dest.initOpaque(convertInner(src, Dest.Inner));
    }

    return convertInner(src, Dest);
}

// Testing namespace
pub const testing = @import("testing.zig");

// Run all tests
test {
    std.testing.refAllDeclsRecursive(@This());
}
