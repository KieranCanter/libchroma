// examples/palette.zig -- generate a perceptually uniform palette by rotating hue in OKLCH

const std = @import("std");
const chroma = @import("libchroma");

pub fn main(init: std.process.Init) !void {
    var buf: [4096]u8 = undefined;
    var w = std.Io.File.stdout().writer(init.io, &buf);
    const out = &w.interface;

    const base = chroma.Oklch(f32).init(0.7, 0.15, 30);
    const steps = 6;

    try out.print("OKLCH palette (L={d:.2}, C={d:.2}, {d} hue steps):\n", .{ base.l, base.c, steps });

    for (0..steps) |i| {
        const hue = @mod(base.h.? + @as(f32, @floatFromInt(i)) * (360.0 / steps), 360.0);
        const color = chroma.Oklch(f32).init(base.l, base.c, hue);
        const srgb = chroma.gamut.gamutMap(color, chroma.Srgb(f32));
        const hex = srgb.toHex();
        try out.print("  H ={d:>6.0}°  #{X:0>6}\n", .{ hue, hex });
    }

    try out.flush();
}
