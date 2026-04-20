// examples/comptime.zig -- comptime generics: same code, different precisions

const std = @import("std");
const chroma = @import("libchroma");

fn showConversion(comptime T: type, init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &buf);
    const out = &w.interface;

    const srgb = chroma.Srgb(T).init(0.8, 0.4, 0.2);
    const hsl = chroma.convert(srgb, chroma.Hsl(T));
    const lab = chroma.convert(srgb, chroma.CieLab(T));

    try out.print("{s}:\n", .{@typeName(T)});
    try out.print("  srgb -> hsl:  ({d:.4}, {d:.4}, {d:.4})\n", .{ hsl.h.?, hsl.s, hsl.l });
    try out.print("  srgb -> lab:  ({d:.4}, {d:.4}, {d:.4})\n", .{ lab.l, lab.a, lab.b });
    try out.flush();
}

pub fn main(init: std.process.Init) !void {
    try showConversion(f32, init);
    try showConversion(f64, init);
}
