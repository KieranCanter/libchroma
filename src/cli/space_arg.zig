const std = @import("std");
const lib = @import("libchroma");

const Writer = std.Io.Writer;

pub const SpaceArg = enum {
    srgb,
    @"srgb-u8",
    @"linear-srgb",
    hsl,
    hsv,
    hwb,
    hsi,
    cmyk,
    lab,
    lch,
    oklab,
    oklch,
    @"display-p3",
    @"linear-display-p3",
    rec2020,
    @"rec2020-scene",
    @"linear-rec2020",
    xyz,
    yxy,

    pub fn fromString(name: []const u8) ?SpaceArg {
        return std.meta.stringToEnum(SpaceArg, name);
    }

    pub fn print(self: SpaceArg, w: *Writer, xyz: lib.Xyz(f32)) Writer.Error!void {
        const name = @tagName(self);
        switch (self) {
            .srgb => try printSpace(w, name, lib.Srgb(f32).fromXyz(xyz)),
            .@"srgb-u8" => try printSpace(w, name, lib.Srgb(u8).fromXyz(xyz)),
            .@"linear-srgb" => try printSpace(w, name, lib.LinearSrgb(f32).fromXyz(xyz)),
            .hsl => try printSpace(w, name, lib.Hsl(f32).fromXyz(xyz)),
            .hsv => try printSpace(w, name, lib.Hsv(f32).fromXyz(xyz)),
            .hwb => try printSpace(w, name, lib.Hwb(f32).fromXyz(xyz)),
            .hsi => try printSpace(w, name, lib.Hsi(f32).fromXyz(xyz)),
            .cmyk => try printSpace(w, name, lib.Cmyk(f32).fromXyz(xyz)),
            .lab => try printSpace(w, name, lib.Lab(f32).fromXyz(xyz)),
            .lch => try printSpace(w, name, lib.Lch(f32).fromXyz(xyz)),
            .oklab => try printSpace(w, name, lib.Oklab(f32).fromXyz(xyz)),
            .oklch => try printSpace(w, name, lib.Oklch(f32).fromXyz(xyz)),
            .@"display-p3" => try printSpace(w, name, lib.DisplayP3(f32).fromXyz(xyz)),
            .@"linear-display-p3" => try printSpace(w, name, lib.LinearDisplayP3(f32).fromXyz(xyz)),
            .rec2020 => try printSpace(w, name, lib.Rec2020(f32).fromXyz(xyz)),
            .@"rec2020-scene" => try printSpace(w, name, lib.Rec2020Scene(f32).fromXyz(xyz)),
            .@"linear-rec2020" => try printSpace(w, name, lib.LinearRec2020(f32).fromXyz(xyz)),
            .xyz => try printSpace(w, name, xyz),
            .yxy => try printSpace(w, name, lib.Yxy(f32).fromXyz(xyz)),
        }
    }

    fn printSpace(w: *Writer, name: []const u8, color: anytype) Writer.Error!void {
        try w.print("{s}({f})\n", .{ name, color });
    }

    pub fn printNames(w: *Writer) void {
        inline for (@typeInfo(SpaceArg).@"enum".fields) |field| {
            w.print("  {s}\n", .{field.name}) catch {};
        }
    }
};

// When adding a new space: update both SpaceArg (above) and parseFunc in parse.zig.
comptime {
    // Safety check: if this fails, a space was added/removed without updating the count.
    // Update this number AND parse.zig's parseFunc when changing spaces.
    const expected_spaces = 19;
    if (@typeInfo(SpaceArg).@"enum".fields.len != expected_spaces)
        @compileError("SpaceArg count changed — update parse.zig's parseFunc and this check");
}
