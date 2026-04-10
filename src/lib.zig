const std = @import("std");

// C ABI exports (pull in so export fn symbols are included in the library)
comptime {
    _ = @import("c/chroma.zig");
}

// Namespaces
// Access the full module: chroma.rgb, chroma.gamut, chroma.alpha, etc.

pub const color = @import("color.zig");
pub const alpha = @import("color/alpha.zig");
pub const gamut = @import("gamut.zig");
pub const testing = @import("testing.zig");

// Convenience shortcuts for major types like Colors and Alpha

// Runtime color type
pub const Color = color.Color;
pub const Space = color.Space;
pub const AlphaColor = color.AlphaColor;

// Color space types
pub const Cmyk = color.Cmyk;
pub const Hsi = color.Hsi;
pub const Hsl = color.Hsl;
pub const Hsv = color.Hsv;
pub const Hwb = color.Hwb;
pub const CieLab = color.CieLab;
pub const CieLch = color.CieLch;
pub const CieXyz = color.CieXyz;
pub const CieYxy = color.CieYxy;
pub const Oklab = color.Oklab;
pub const Oklch = color.Oklch;
pub const Srgb = color.Srgb;
pub const LinearSrgb = color.LinearSrgb;
pub const DisplayP3 = color.DisplayP3;
pub const LinearDisplayP3 = color.LinearDisplayP3;
pub const Rec2020 = color.Rec2020;
pub const Rec2020Scene = color.Rec2020Scene;
pub const LinearRec2020 = color.LinearRec2020;
pub const RgbError = color.RgbError;

// Alpha wrapper
pub const Alpha = alpha.Alpha;

// Color interface contract
const validation = @import("validation.zig");
pub const assertColorInterface = validation.assertColorInterface;

// Universal conversion (comptime)

pub fn convert(src: anytype, comptime Dest: type) Dest {
    const Src = @TypeOf(src);
    assertColorInterface(Src);
    assertColorInterface(Dest);

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

            return DestColor.fromCieXyz(src_color.toCieXyz());
        }
    }.func;

    const src_is_alpha = alpha.isAlpha(Src);
    const dest_is_alpha = alpha.isAlpha(Dest);

    // Alpha -> Alpha
    if (src_is_alpha and dest_is_alpha) {
        return Dest.init(
            convertInner(src.color, Dest.Inner),
            src.alpha,
        );
    }

    // Alpha -> Opaque
    if (src_is_alpha) {
        return convertInner(src.color, Dest);
    }

    // Opaque -> Alpha
    if (dest_is_alpha) {
        return Dest.initOpaque(convertInner(src, Dest.Inner));
    }

    return convertInner(src, Dest);
}

// Tests

test {
    std.testing.refAllDeclsRecursive(@This());
}
