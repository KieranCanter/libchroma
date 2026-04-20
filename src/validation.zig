const std = @import("std");

const CieXyz = @import("color/xyz/cie_xyz.zig").CieXyz;

const alpha = @import("color/alpha.zig");

/// Comptime check that T implements the color interface (toCieXyz, fromCieXyz, Backing).
pub inline fn assertColorInterface(comptime T: type) void {
    comptime {
        if (alpha.isAlpha(T)) {
            assertColorInterface(T.Inner);
            return;
        }

        const color_space_name = colorSpaceName(T);
        if (!std.meta.hasMethod(T, "toCieXyz")) {
            @compileError(color_space_name ++ " must define a `toCieXyz()` method");
        }
        if (!std.meta.hasMethod(T, "fromCieXyz")) {
            @compileError(color_space_name ++ " must define a `fromCieXyz()` method");
        }
        if (!@hasDecl(T, "Backing")) {
            @compileError(color_space_name ++ " must expose its backing type in a `Backing` field e.g. `pub const Backing = T`");
        }
    }
}

/// Comptime assert that T is u8 or a float type.
pub inline fn assertRgbType(comptime T: type) void {
    comptime switch (@typeInfo(T)) {
        .int => {
            if (T == u8) {
                return;
            } else {
                @compileError("RGB value type must be u8 or a float type");
            }
        },
        .float => return,
        else => @compileError("RGB value type must be u8 or a float type"),
    };
}

/// Comptime assert that T is a float type.
pub inline fn assertFloatType(comptime T: type) void {
    comptime switch (@typeInfo(T)) {
        .float => return,
        else => @compileError("Value type must be a float type"),
    };
}

/// Maps u8 -> f32, passes float types through unchanged.
pub inline fn rgbToFloatType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .float => T,
        .int => f32,
        else => unreachable,
    };
}

/// Extract a short human-readable name from a color space type at comptime.
pub inline fn colorSpaceName(comptime T: type) []const u8 {
    comptime {
        const maybe_last_dot = std.mem.lastIndexOfScalar(u8, @typeName(T), '.');
        if (maybe_last_dot) |last_dot| {
            const maybe_open_paren = std.mem.indexOfScalarPos(u8, @typeName(T), last_dot + 1, '(');
            if (maybe_open_paren) |open_paren| {
                const closing_paren = std.mem.indexOfScalarPos(u8, @typeName(T), open_paren, ')').?;
                return @typeName(T)[last_dot + 1 .. closing_paren + 1];
            }
            const maybe_closing_paren = std.mem.indexOfScalarPos(u8, @typeName(T), last_dot + 1, ')');
            if (maybe_closing_paren) |closing_paren| {
                return @typeName(T)[last_dot + 1 .. closing_paren];
            }
            return @typeName(T)[last_dot + 1 ..];
        } else {
            return @typeName(T);
        }
    }
}
