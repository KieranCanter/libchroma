const std = @import("std");

const Xyz = @import("color_space/xyz.zig").Xyz;

// Color interface validation
pub inline fn assertColorInterface(comptime T: type) void {
    comptime if (std.mem.endsWith(u8, @typeName(T), "Xyz(f32)") or std.mem.endsWith(u8, @typeName(T), "Xyz(f64)")) {
        return;
    };
    comptime if (!@hasDecl(T, "toXyz")) {
        @compileError(@typeName(T) ++ " must define a `toXyz()` method");
    };
    comptime if (!@hasDecl(T, "fromXyz")) {
        @compileError(@typeName(T) ++ " must define a `fromXyz()` method");
    };
}

// RGB type validation
pub inline fn assertRgbType(comptime T: type) void {
    comptime if (T == u8 or T == f32 or T == f64) return;
    @compileError("RGB value type must be one of: u8, f32, f64");
}

// Float type validation
pub inline fn assertFloatType(comptime T: type) void {
    comptime if (T == f32 or T == f64) return;
    @compileError("Value type must be a float: f32, f64");
}

// Default to f32 when going from a u8 in RGB to float-only type
pub inline fn rgbToFloatType(comptime T: type) type {
    return switch (T) {
        f32, f64 => T,
        u8 => f32,
        else => unreachable,
    };
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
