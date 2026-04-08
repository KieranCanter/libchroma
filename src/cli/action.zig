const std = @import("std");
const Allocator = std.mem.Allocator;

const convert = @import("convert.zig");
const show = @import("show.zig");
const SpaceArg = @import("space_arg.zig").SpaceArg;

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

        stdout.writeAll("Available spaces:\n") catch {};
        SpaceArg.printNames(stdout);
        stdout.flush() catch {};
    }

    const help_convert =
        \\Convert a color to a target color space.
        \\
        \\Usage: chroma convert <color> <space>
        \\
        \\Color formats:
        \\  #RRGGBB            Hex with hash
        \\  RRGGBB             Hex without hash
        \\  rgb(r, g, b)       RGB with values 0-255
        \\  space(v1, v2, v3)  Any supported color space
        \\
        \\Example:
        \\  chroma convert "#C86432" oklch
        \\  chroma convert "oklch(0.6138, 0.1423, 45.08)" srgb
        \\
    ;

    const help_show =
        \\Show a color in all supported color spaces.
        \\
        \\Usage: chroma show <color>
        \\
        \\Color formats:
        \\  #RRGGBB            Hex with hash
        \\  RRGGBB             Hex without hash
        \\  rgb(r, g, b)       RGB with values 0-255
        \\  space(v1, v2, v3)  Any supported color space
        \\
        \\Example:
        \\  chroma show "#C86432"
        \\  chroma show "oklch(0.6138, 0.1423, 45.08)"
        \\
    ;
};
