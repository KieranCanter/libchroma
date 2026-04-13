const std = @import("std");
const lib = @import("libchroma");
const Allocator = std.mem.Allocator;
const convert = @import("convert.zig");
const fmt = @import("format.zig");
const info = @import("info.zig");

pub const ActionError = error{HelpRequested};

pub const Action = enum {
    convert,
    info,

    pub fn run(self: Action, alloc: Allocator, args: *std.process.ArgIterator) !void {
        return switch (self) {
            .convert => convert.run(alloc, args),
            .info => info.run(alloc, args),
        } catch |err| switch (err) {
            ActionError.HelpRequested => self.printHelp(),
            else => return err,
        };
    }

    fn printHelp(self: Action) void {
        var buf: [4096]u8 = undefined;
        var w = std.fs.File.stdout().writer(&buf);
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
