const std = @import("std");
const lib = @import("libchroma");

const Writer = std.Io.Writer;

pub const Options = struct {
    precision: u8 = 2,
    json: bool = false,
};

/// Match a CLI name (hyphens) to a Space tag (underscores).
/// Also supports short aliases: "xyz" -> .cie_xyz, "lab" -> .cie_lab, etc.
pub fn spaceFromCliName(name: []const u8) ?lib.Space {
    const aliases = .{
        .{ "xyz", "cie_xyz" },
        .{ "yxy", "cie_yxy" },
        .{ "lab", "cie_lab" },
        .{ "lch", "cie_lch" },
        .{ "rgb", "srgb" },
    };
    inline for (aliases) |a| {
        if (std.mem.eql(u8, name, a[0])) return std.meta.stringToEnum(lib.Space, a[1]);
    }
    var buf: [64]u8 = undefined;
    if (name.len > buf.len) return null;
    @memcpy(buf[0..name.len], name);
    std.mem.replaceScalar(u8, buf[0..name.len], '-', '_');
    return std.meta.stringToEnum(lib.Space, buf[0..name.len]);
}

/// Get the CLI display name for a Space (underscores → hyphens). Comptime only.
pub fn spaceCliName(comptime space: lib.Space) []const u8 {
    const tag = @tagName(space);
    var buf: [tag.len]u8 = undefined;
    @memcpy(&buf, tag);
    std.mem.replaceScalar(u8, &buf, '_', '-');
    const result = buf;
    return &result;
}

/// Format a Color with its CLI space name prefix, e.g. "oklch(0.61, 0.14, 45.08)".
pub fn formatColor(color: lib.Color, opts: Options, w: *Writer) Writer.Error!void {
    switch (color) {
        inline else => |c, tag| {
            try w.print("{s}(", .{comptime spaceCliName(tag)});
            try formatValues(c, opts, w);
            try w.writeAll(")");
        },
    }
}

/// Format just the comma-separated values of a color struct.
pub fn formatValues(c: anytype, opts: Options, w: *Writer) Writer.Error!void {
    const fields = @typeInfo(@TypeOf(c)).@"struct".fields;
    inline for (fields, 0..) |f, i| {
        if (i > 0) try w.writeAll(", ");
        try formatField(@field(c, f.name), f.type, opts, w);
    }
}

/// Format a single Color as JSON: {"space":"oklch","l":0.61,"c":0.14,"h":45.08}
pub fn formatColorJson(color: lib.Color, opts: Options, w: *Writer) Writer.Error!void {
    switch (color) {
        inline else => |c, tag| {
            try w.print("{{\"space\":\"{s}\"", .{comptime spaceCliName(tag)});
            const fields = @typeInfo(@TypeOf(c)).@"struct".fields;
            inline for (fields) |f| {
                try w.print(",\"{s}\":", .{f.name});
                try formatFieldJson(@field(c, f.name), f.type, opts, w);
            }
            try w.writeAll("}");
        },
    }
}

/// Format all spaces as JSON: {"cie-xyz":{...},"srgb":{...},...}
pub fn formatAllJson(input: lib.Color, opts: Options, w: *Writer) Writer.Error!void {
    @setEvalBranchQuota(10000);
    try w.writeAll("{");
    inline for (@typeInfo(lib.Space).@"enum".fields, 0..) |field, i| {
        const space: lib.Space = @enumFromInt(field.value);
        const result = lib.color.convert(input, space);
        if (i > 0) try w.writeAll(",");
        try w.print("\"{s}\":{{", .{comptime spaceCliName(space)});
        switch (result) {
            inline else => |c| {
                const fields = @typeInfo(@TypeOf(c)).@"struct".fields;
                inline for (fields, 0..) |f, fi| {
                    if (fi > 0) try w.writeAll(",");
                    try w.print("\"{s}\":", .{f.name});
                    try formatFieldJson(@field(c, f.name), f.type, opts, w);
                }
            },
        }
        try w.writeAll("}");
    }
    try w.writeAll("}");
}

fn formatField(val: anytype, comptime T: type, opts: Options, w: *Writer) Writer.Error!void {
    if (T == ?f32) {
        if (val) |v| {
            try formatFloat(v, opts.precision, w);
        } else {
            try w.writeAll("none");
        }
    } else {
        try formatFloat(val, opts.precision, w);
    }
}

fn formatFieldJson(val: anytype, comptime T: type, opts: Options, w: *Writer) Writer.Error!void {
    if (T == ?f32) {
        if (val) |v| {
            try formatFloat(v, opts.precision, w);
        } else {
            try w.writeAll("null");
        }
    } else {
        try formatFloat(val, opts.precision, w);
    }
}

pub fn formatFloat(val: f32, precision: u8, w: *Writer) Writer.Error!void {
    var rounded = @round(val * p10(precision)) / p10(precision);
    // Eliminate negative zero
    if (rounded == 0) rounded = 0;
    try w.print("{d}", .{rounded});
}

pub fn p10(n: u8) f32 {
    var result: f32 = 1;
    for (0..n) |_| result *= 10;
    return result;
}
