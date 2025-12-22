const std = @import("std");

// Color interface validation
pub inline fn assertColorInterface(comptime C: type) void {
    comptime if (!@hasDecl(C, "toXyz")) {
        @compileError(@typeName(C) ++ " must define a `toXyz()` method");
    };
    comptime if (!@hasDecl(C, "fromXyz")) {
        @compileError(@typeName(C) ++ " must define a `fromXyz()` method");
    };
}

// Hue type validation
pub inline fn assertRgbType(comptime T: type) void {
    comptime if (T == u8 or T == f32 or T == f64) return;
    @compileError("RGB value type must be one of: u8, f32, f64");
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
        try std.testing.expectApproxEqAbs(eval, aval, tolerance);
    }
}
