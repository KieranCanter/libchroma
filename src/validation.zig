const std = @import("std");

const Xyz = @import("color_space/xyz.zig").Xyz;

// Color interface validation
pub inline fn assertColorInterface(comptime T: type) void {
    comptime {
        const color_space_name = colorSpaceName(T);
        if (std.mem.containsAtLeast(u8, color_space_name, 1, "Xyz")) {
            return;
        }
        if (!std.meta.hasMethod(T, "toXyz")) {
            @compileError(color_space_name ++ " must define a `toXyz()` method");
        }
        if (!std.meta.hasMethod(T, "fromXyz")) {
            @compileError(color_space_name ++ " must define a `fromXyz()` method");
        }
    }
}

// RGB type validation
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

// Float type validation
pub inline fn assertFloatType(comptime T: type) void {
    comptime switch (@typeInfo(T)) {
        .float => return,
        else => @compileError("Value type must be a float type"),
    };
}

// Default to f32 when going from a u8 in RGB to float-only type
pub inline fn rgbToFloatType(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .float => T,
        .int => f32,
        else => unreachable,
    };
}

pub inline fn colorSpaceName(comptime T: type) []const u8 {
    comptime {
        const maybe_last_dot = std.mem.lastIndexOfScalar(u8, @typeName(T), '.');
        if (maybe_last_dot) |last_dot| {
            return @typeName(T)[last_dot + 1 ..];
        } else {
            return @typeName(T);
        }
    }
}

// Wrapper for expectApproxEqAbs for comparing float fields of a color
pub inline fn expectColorsApproxEqAbs(expected: anytype, actual: anytype, tolerance: anytype) !void {
    const E = @TypeOf(expected);
    const A = @TypeOf(actual);
    assertColorInterface(E);
    assertColorInterface(A);

    const einfo = @typeInfo(E).@"struct";
    const ainfo = @typeInfo(A).@"struct";
    comptime if (einfo.fields.len != ainfo.fields.len) {
        @compileError("Cannot compare structs of unequal sizes");
    };

    inline for (einfo.fields, ainfo.fields) |efield, afield| {
        comptime if (!std.mem.eql(u8, efield.name, afield.name)) {
            @compileError("Struct field name mismatch. Expected: " ++ efield.name ++ ", actual: " ++ afield.name);
        };
        comptime if (efield.type != afield.type) {
            @compileError("Struct field name mismatch. Expected: " ++ efield.type ++ ", actual: " ++ afield.type);
        };
        const eval = @field(expected, efield.name);
        const aval = @field(actual, afield.name);

        // Color fields could be u8, f32, f64, ?f32, or ?f64
        switch (@typeInfo(efield.type)) {
            .int => try std.testing.expectApproxEqAbs(@as(f32, @floatFromInt(eval)), @as(f32, @floatFromInt(aval)), tolerance),
            .float => try std.testing.expectApproxEqAbs(eval, aval, tolerance),
            .optional => try std.testing.expectApproxEqAbs(eval.?, aval.?, tolerance),
            else => unreachable,
        }
    }
}
