const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const convert = @import("convert.zig");
const fmt = @import("format.zig");
const show = @import("show.zig");

pub const ActionError = error{HelpRequested};

pub const Action = enum {
    convert,
    show,

    pub fn run(self: Action, alloc: Allocator, args: *std.process.ArgIterator) !void {
        return switch (self) {
            .convert => convert.run(alloc, args),
            .show => show.run(alloc, args),
        } catch |err| switch (err) {
            ActionError.HelpRequested => self.printHelp(),
            else => return err,
        };
    }

    fn printHelp(self: Action) void {
        var buf: [4096]u8 = undefined;
        var w = std.fs.File.stdout().writer(&buf);
        const stdout = &w.interface;

        const output = switch (self) {
            .convert => help_convert,
            .show => help_show,
        };
        stdout.writeAll(output) catch {};

        stdout.writeAll("\nAvailable spaces:\n") catch {};
        inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
            const space: lib.Space = @enumFromInt(field.value);
            stdout.print("  {s}\n", .{comptime fmt.spaceCliName(space)}) catch {};
        }
        stdout.flush() catch {};
    }

    const help_convert =
        \\Convert a color to a target color space.
        \\
        \\Usage: chroma convert <color> <space> [options]
        \\
        \\Options:
        \\  --precision N      Decimal places (default: 2)
        \\  --json             Output as JSON
        \\
        \\Color formats:
        \\  #RRGGBB            Hex with hash
        \\  RRGGBB             Hex without hash
        \\  rgb(r, g, b)       RGB with values 0-255 (auto-detected) or 0-1
        \\  space(v1, v2, v3)  Any supported color space
        \\
        \\Example:
        \\  chroma convert "#C86432" oklch
        \\  chroma convert "#C86432" oklch --json
        \\
    ;

    const help_show =
        \\Show a color in all supported color spaces.
        \\
        \\Usage: chroma show <color> [options]
        \\
        \\Options:
        \\  --precision N      Decimal places (default: 2)
        \\  --json             Output as JSON
        \\
        \\Color formats:
        \\  #RRGGBB            Hex with hash
        \\  RRGGBB             Hex without hash
        \\  rgb(r, g, b)       RGB with values 0-255 (auto-detected) or 0-1
        \\  space(v1, v2, v3)  Any supported color space
        \\
        \\Example:
        \\  chroma show "#C86432"
        \\  chroma show "#C86432" --json --precision 4
        \\
    ;
};
