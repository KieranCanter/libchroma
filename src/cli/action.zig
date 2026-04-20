const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const Io = std.Io;
const convert = @import("convert.zig");
const fmt = @import("format.zig");
const info = @import("info.zig");

/// Signals that the user asked for --help instead of running a command.
pub const ActionError = error{HelpRequested};

/// Top-level CLI subcommand.
pub const Action = enum {
    convert,
    info,

    pub fn run(self: Action, alloc: Allocator, io: Io, args: *std.process.Args.Iterator) !void {
        return switch (self) {
            .convert => convert.run(alloc, io, args),
            .info => info.run(alloc, io, args),
        } catch |err| switch (err) {
            ActionError.HelpRequested => self.printHelp(io),
            else => return err,
        };
    }

    fn printHelp(self: Action, io: Io) void {
        var buf: [4096]u8 = undefined;
        var w = std.Io.File.stdout().writer(io, &buf);
        const stdout = &w.interface;

        stdout.writeAll(switch (self) {
            .convert => convert.help,
            .info => info.help,
        }) catch {};

        stdout.writeAll("\nAvailable spaces:\n") catch {};
        inline for (@typeInfo(lib.Space).@"enum".fields) |field| {
            const space: lib.Space = @enumFromInt(field.value);
            stdout.print("  {s}\n", .{comptime fmt.spaceCliName(space)}) catch {};
        }
        stdout.flush() catch {};
    }
};
