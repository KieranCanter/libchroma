// Color string parser for CLI.
// Supports: #RRGGBB, RRGGBB, and space(v1, v2, ...) for all color spaces.

const std = @import("std");
const lib = @import("libchroma");

pub const ParseError = error{
    InvalidHexFormat,
    InvalidFuncFormat,
    InvalidFormat,
    InvalidValues,
    UnknownSpace,
};

pub const CommandArgs = struct {
    xyz: lib.Xyz(f32),
};

/// Extract and parse the color arg from an existing arg iterator.
/// Returns null if --help is requested or no color arg is provided.
pub fn parseCommandArgs(args: *std.process.ArgIterator) ParseError!?CommandArgs {
    const color_str = args.next() orelse return null;
    if (std.mem.eql(u8, color_str, "--help") or std.mem.eql(u8, color_str, "-h"))
        return null;

    const xyz = try parse(color_str);
    return .{ .xyz = xyz };
}

/// Parse a color string and return it as XYZ for uniform interchange.
pub fn parse(input: []const u8) ParseError!lib.Xyz(f32) {
    const s = std.mem.trim(u8, input, " \t");
    if (isHexLike(s)) return parseHex(s);
    if (std.mem.indexOfScalar(u8, s, '(') != null) return parseFunc(s);
    return ParseError.InvalidFormat;
}

fn isHexLike(s: []const u8) bool {
    if (s.len == 0) return false;
    if (s[0] == '#') return true;
    if (s.len == 6) {
        for (s) |c| {
            if (!std.ascii.isHex(c)) return false;
        }
        return true;
    }
    return false;
}

fn parseHex(s: []const u8) ParseError!lib.Xyz(f32) {
    const hex_str = if (s[0] == '#') s[1..] else s;
    if (hex_str.len != 6) return ParseError.InvalidHexFormat;
    const srgb = lib.Srgb(f32).initFromHexString(hex_str) catch return ParseError.InvalidHexFormat;
    return srgb.toXyz();
}

fn parseFunc(s: []const u8) ParseError!lib.Xyz(f32) {
    const paren = std.mem.indexOfScalar(u8, s, '(') orelse return ParseError.InvalidFuncFormat;
    if (s.len == 0 or s[s.len - 1] != ')') return ParseError.InvalidFuncFormat;

    const name = s[0..paren];
    const inner = s[paren + 1 .. s.len - 1];

    var vals: [4]f32 = undefined;
    var count: usize = 0;
    var it = std.mem.splitAny(u8, inner, ", %");
    while (count < 4) {
        const v = nextFloat(&it) orelse break;
        vals[count] = v;
        count += 1;
    }

    if (count == 3) {
        const a = vals[0];
        const b = vals[1];
        const c = vals[2];

        if (std.mem.eql(u8, name, "srgb")) return lib.Srgb(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "srgb-u8") or std.mem.eql(u8, name, "rgb")) return lib.Srgb(f32).init(a / 255.0, b / 255.0, c / 255.0).toXyz();
        if (std.mem.eql(u8, name, "linear-srgb")) return lib.LinearSrgb(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "hsl")) return lib.Hsl(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "hsv")) return lib.Hsv(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "hwb")) return lib.Hwb(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "hsi")) return lib.Hsi(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "lab")) return lib.Lab(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "lch")) return lib.Lch(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "oklab")) return lib.Oklab(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "oklch")) return lib.Oklch(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "display-p3")) return lib.DisplayP3(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "linear-display-p3")) return lib.LinearDisplayP3(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "rec2020")) return lib.Rec2020(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "rec2020-scene")) return lib.Rec2020Scene(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "linear-rec2020")) return lib.LinearRec2020(f32).init(a, b, c).toXyz();
        if (std.mem.eql(u8, name, "xyz")) return lib.Xyz(f32).init(a, b, c);
        if (std.mem.eql(u8, name, "yxy")) return lib.Yxy(f32).init(a, b, c).toXyz();
        return ParseError.UnknownSpace;
    }

    if (count == 4) {
        if (std.mem.eql(u8, name, "cmyk")) return lib.Cmyk(f32).init(vals[0], vals[1], vals[2], vals[3]).toXyz();
        return ParseError.UnknownSpace;
    }

    return ParseError.InvalidValues;
}

fn nextFloat(it: anytype) ?f32 {
    while (it.next()) |tok| {
        const trimmed = std.mem.trim(u8, tok, " \t");
        if (trimmed.len == 0) continue;
        return std.fmt.parseFloat(f32, trimmed) catch return null;
    }
    return null;
}
