const std = @import("std");
const validation = @import("validation.zig");

// Wrapper for expectApproxEqAbs for comparing float fields of a color
pub inline fn expectColorsApproxEqAbs(expected: anytype, actual: anytype, tolerance: anytype) !void {
    const E = @TypeOf(expected);
    const A = @TypeOf(actual);
    validation.assertColorInterface(E);
    validation.assertColorInterface(A);

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

