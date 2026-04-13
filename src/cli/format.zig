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

/// Get the CLI display name for a Space.
pub fn spaceCliName(comptime space: lib.Space) []const u8 {
    // Friendlier display names
    return switch (space) {
        .cie_xyz => "xyz",
        .cie_yxy => "yxy",
        .cie_lab => "lab",
        .cie_lch => "lch",
        else => {
            const tag = @tagName(space);
            var buf: [tag.len]u8 = undefined;
            @memcpy(&buf, tag);
            std.mem.replaceScalar(u8, &buf, '_', '-');
            const result = buf;
            return &result;
        },
    };
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

/// Format a single Color as JSON: {"space":"oklch","l":0.61,"c":0.14,"h":45.08,"alpha":0.5}
pub fn formatColorJson(c: lib.Color, alpha: ?f32, opts: Options, w: *Writer) Writer.Error!void {
    switch (c) {
        inline else => |v, tag| {
            try w.print("{{\"space\":\"{s}\"", .{comptime spaceCliName(tag)});
            const fields = @typeInfo(@TypeOf(v)).@"struct".fields;
            inline for (fields) |f| {
                try w.print(",\"{s}\":", .{f.name});
                try formatFieldJson(@field(v, f.name), f.type, opts, w);
            }
            if (alpha) |a| {
                try w.writeAll(",\"alpha\":");
                try formatFloat(a, opts.precision, w);
            }
            try w.writeAll("}");
        },
    }
}

/// Format all spaces as JSON: {"alpha":0.5,"cie-xyz":{...},"srgb":{...},...}
pub fn formatAllJson(input: lib.Color, alpha: ?f32, opts: Options, w: *Writer) Writer.Error!void {
    return formatFilteredJson(input, alpha, std.EnumSet(lib.Space).initFull(), opts, w);
}

/// Format filtered spaces as JSON.
pub fn formatFilteredJson(input: lib.Color, alpha: ?f32, filter: std.EnumSet(lib.Space), opts: Options, w: *Writer) Writer.Error!void {
    @setEvalBranchQuota(10_000);
    try w.writeAll("{");
    var first = true;
    if (alpha) |a| {
        try w.writeAll("\"alpha\":");
        try formatFloat(a, opts.precision, w);
        first = false;
    }
    inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
        const space: lib.Space = @enumFromInt(field.value);
        if (filter.contains(space)) {
            if (!first) try w.writeAll(",");
            first = false;
            const result = lib.color.convert(input, space);
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

// ============================================================================
// TESTS
// ============================================================================

const testing = std.testing;

fn testFormat(comptime f: anytype, args: anytype) ![]const u8 {
    var buf: [4096]u8 = undefined;
    var w = std.io.fixedBufferStream(&buf);
    const writer = w.writer().any();
    try @call(.auto, f, .{&writer} ++ args);
    return buf[0..w.pos];
}

test "spaceFromCliName basic" {
    try testing.expectEqual(.srgb, spaceFromCliName("srgb"));
    try testing.expectEqual(.oklch, spaceFromCliName("oklch"));
    try testing.expectEqual(.linear_srgb, spaceFromCliName("linear-srgb"));
}

test "spaceFromCliName aliases" {
    try testing.expectEqual(.srgb, spaceFromCliName("rgb"));
    try testing.expectEqual(.cie_xyz, spaceFromCliName("xyz"));
    try testing.expectEqual(.cie_lab, spaceFromCliName("lab"));
    try testing.expectEqual(.cie_lch, spaceFromCliName("lch"));
    try testing.expectEqual(.cie_yxy, spaceFromCliName("yxy"));
}

test "spaceFromCliName unknown" {
    try testing.expectEqual(@as(?lib.Space, null), spaceFromCliName("fakespace"));
}

test "formatFloat precision" {
    var buf: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    try formatFloat(0.12345, 2, &w);
    try testing.expectEqualStrings("0.12", buf[0..stream.pos]);
}

test "formatFloat negative zero" {
    var buf: [64]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    try formatFloat(-0.0001, 2, &w);
    try testing.expectEqualStrings("0", buf[0..stream.pos]);
}

test "spaceCliName strips cie prefix" {
    try testing.expectEqualStrings("xyz", spaceCliName(.cie_xyz));
    try testing.expectEqualStrings("yxy", spaceCliName(.cie_yxy));
    try testing.expectEqualStrings("lab", spaceCliName(.cie_lab));
    try testing.expectEqualStrings("lch", spaceCliName(.cie_lch));
}

test "spaceCliName preserves other names" {
    try testing.expectEqualStrings("srgb", spaceCliName(.srgb));
    try testing.expectEqualStrings("oklch", spaceCliName(.oklch));
    try testing.expectEqualStrings("linear-srgb", spaceCliName(.linear_srgb));
}

test "formatColor output" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    const color = lib.Color{ .srgb = lib.Srgb(f32).init(0.78, 0.39, 0.2) };
    try formatColor(color, .{}, &w);
    try testing.expectEqualStrings("srgb(0.78, 0.39, 0.2)", buf[0..stream.pos]);
}

test "formatColorJson without alpha" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    const color = lib.Color{ .srgb = lib.Srgb(f32).init(0.78, 0.39, 0.2) };
    try formatColorJson(color, null, .{}, &w);
    try testing.expectEqualStrings("{\"space\":\"srgb\",\"r\":0.78,\"g\":0.39,\"b\":0.2}", buf[0..stream.pos]);
}

test "formatColorJson with alpha" {
    var buf: [256]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    const color = lib.Color{ .srgb = lib.Srgb(f32).init(0.78, 0.39, 0.2) };
    try formatColorJson(color, 0.5, .{}, &w);
    try testing.expectEqualStrings("{\"space\":\"srgb\",\"r\":0.78,\"g\":0.39,\"b\":0.2,\"alpha\":0.5}", buf[0..stream.pos]);
}

test "formatFilteredJson shows only filtered spaces" {
    var buf: [4096]u8 = undefined;
    var stream = std.io.fixedBufferStream(&buf);
    const w = stream.writer().any();
    const color = lib.Color{ .srgb = lib.Srgb(f32).init(0.78, 0.39, 0.2) };
    var filter = std.EnumSet(lib.Space).initEmpty();
    filter.insert(.srgb);
    filter.insert(.oklch);
    try formatFilteredJson(color, null, filter, .{}, &w);
    const result = buf[0..stream.pos];
    // Should contain srgb and oklch but not others
    try testing.expect(std.mem.indexOf(u8, result, "\"srgb\"") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"oklch\"") != null);
    try testing.expect(std.mem.indexOf(u8, result, "\"cmyk\"") == null);
    try testing.expect(std.mem.indexOf(u8, result, "\"hsl\"") == null);
}

test "formatFilteredJson full set matches formatAllJson" {
    var buf1: [8192]u8 = undefined;
    var buf2: [8192]u8 = undefined;
    var s1 = std.io.fixedBufferStream(&buf1);
    var s2 = std.io.fixedBufferStream(&buf2);
    const w1 = s1.writer().any();
    const w2 = s2.writer().any();
    const color = lib.Color{ .srgb = lib.Srgb(f32).init(0.78, 0.39, 0.2) };
    try formatAllJson(color, null, .{}, &w1);
    try formatFilteredJson(color, null, std.EnumSet(lib.Space).initFull(), .{}, &w2);
    try testing.expectEqualStrings(buf1[0..s1.pos], buf2[0..s2.pos]);
}
