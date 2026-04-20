// examples/basic.zig -- libchroma Zig API overview

const std = @import("std");
const chroma = @import("libchroma");

var line_storage: [128]u8 = undefined;

fn readLine(reader: *std.Io.Reader) ?[]const u8 {
    const line = reader.takeDelimiterInclusive('\n') catch return null;
    const without_delim = if (line.len > 0 and line[line.len - 1] == '\n') line[0 .. line.len - 1] else line;
    const trimmed = std.mem.trim(u8, without_delim, &.{ ' ', '\r', '\t', '"', '\'' });
    if (trimmed.len > line_storage.len) return null;
    @memcpy(line_storage[0..trimmed.len], trimmed);
    return line_storage[0..trimmed.len];
}

pub fn main(init: std.process.Init) !void {
    var out_buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &out_buf);
    const out = &w.interface;

    // --- static demos ---

    // hex init + conversion
    try out.writeAll("--- hex init + conversion ---\n");
    const orange = chroma.Srgb(f32).initFromHex(0xC86432);
    const oklch = chroma.convert(orange, chroma.Oklch(f32));
    try out.print("input:  #C86432\n", .{});
    try out.print("oklch:  L={d:.2} C={d:.2} H={?d:.2}\n\n", .{ oklch.l, oklch.c, oklch.h });

    // gamut mapping
    try out.writeAll("--- gamut mapping ---\n");
    const p3_green = chroma.DisplayP3(f32).init(0, 1, 0);
    const mapped = chroma.gamut.gamutMap(p3_green, chroma.Srgb(f32));
    try out.print("input:  display_p3(0.00, 1.00, 0.00)\n", .{});
    try out.print("mapped: srgb({d:.2}, {d:.2}, {d:.2})\n\n", .{ mapped.r, mapped.g, mapped.b });

    // alpha
    try out.writeAll("--- alpha ---\n");
    const semi = chroma.Alpha(chroma.Srgb(f32)).init(orange, 0.5);
    const semi_oklch = chroma.convert(semi, chroma.Alpha(chroma.Oklch(f32)));
    try out.print("input:  srgb #C86432 with alpha 0.50\n", .{});
    try out.print("alpha preserved after conversion: {d:.2}\n", .{semi_oklch.alpha});

    try out.flush();

    // --- interactive prompt ---

    try out.writeAll("\n--- runtime ---\n");

    var inbuf: [256]u8 = undefined;
    var reader = std.Io.File.stdin().reader(init.io, &inbuf);
    const in = &reader.interface;

    const space_names = comptime blk: {
        const fields = @typeInfo(chroma.Space).@"enum".fields;
        var names: [fields.len][]const u8 = undefined;
        for (fields, 0..) |f, i| names[i] = f.name;
        break :blk names;
    };
    try out.writeAll("space (");
    for (space_names, 0..) |name, i| {
        if (i > 0) try out.writeAll(", ");
        try out.writeAll(name);
    }
    try out.writeAll("): ");
    try out.flush();

    const space_name = readLine(in) orelse return;
    const space = std.meta.stringToEnum(chroma.Space, space_name) orelse {
        try out.print("unknown space: {s}\n", .{space_name});
        try out.flush();
        return;
    };

    const field_names = chroma.color.fieldNames(space);
    var vals: [4]f32 = undefined;
    for (field_names, 0..) |name, i| {
        try out.print("{s}: ", .{name});
        try out.flush();
        const val_str = readLine(in) orelse return;
        vals[i] = std.fmt.parseFloat(f32, val_str) catch {
            try out.print("invalid number: {s}\n", .{val_str});
            try out.flush();
            return;
        };
    }

    const input_color = chroma.color.initFromSlice(space, vals[0..field_names.len]) catch unreachable;

    const srgb = chroma.color.convert(input_color, .srgb);
    const oklch_out = chroma.color.convert(input_color, .oklch);

    try out.writeAll("\n");
    try out.print("{s}: {f}\n", .{ @tagName(space), chroma.color.formatter(input_color, .default) });
    try out.print("srgb: {f}\n", .{chroma.color.formatter(srgb, .default)});
    try out.print("oklch: {f}\n", .{chroma.color.formatter(oklch_out, .default)});
    try out.flush();
}
