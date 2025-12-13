const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("libchroma", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const semver = try incrementBuildNumber(b);
    const staticLib = b.addLibrary(.{
        .name = "chroma",
        .linkage = .static,
        .root_module = mod,
        .version = semver,
    });
    const dynLib = b.addLibrary(.{
        .name = "chroma",
        .linkage = .dynamic,
        .root_module = mod,
        .version = semver,
    });
    b.installArtifact(staticLib);
    b.installArtifact(dynLib);

    const exe = b.addExecutable(.{
        .name = "chroma-cli",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "libchroma", .module = mod },
            },
        }),
    });
    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });

    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}

fn incrementBuildNumber(b: *std.Build) !std.SemanticVersion {
    const alloc = b.allocator;

    // Load in manifest
    const manifest = @embedFile("build.zig.zon");

    // Get the start and end indices of the semver string
    const range = try findVersion(manifest);
    const old_version = manifest[range.start..range.end];
    // Increment the build number of the version
    const new_version = try bumpVersion(alloc, old_version);
    // Concatenate new version with front and end of the manifest to replace old version
    const new_manifest = try std.mem.concat(alloc, u8, &.{ manifest[0..range.start], new_version, manifest[range.end..] });

    // Write new contents to the manifest file
    var file = try std.fs.Dir.openFile(b.build_root.handle, "build.zig.zon", .{ .mode = .write_only });
    defer file.close();
    try file.seekTo(0);
    try file.writeAll(new_manifest);

    // Return the version as a std.SemanticVersion value
    return std.SemanticVersion.parse(new_version);
}

const field: *const [7:0]u8 = "version";
fn findVersion(manifest: []const u8) !struct { start: usize, end: usize } {
    var i: usize = 0;

    while (i + field.len < manifest.len) : (i += 1) {
        if (!std.mem.eql(u8, manifest[i .. i + field.len], field)) continue;

        i += field.len;

        while (i < manifest.len and std.ascii.isWhitespace(manifest[i])) i += 1;

        if (i >= manifest.len or manifest[i] != '=') continue;

        i += 1;

        while (i < manifest.len and std.ascii.isWhitespace(manifest[i])) i += 1;

        if (i >= manifest.len or manifest[i] != '"') return error.MalformedVersion;

        const start = i + 1;
        i = start;

        while (i < manifest.len and manifest[i] != '"') i += 1;

        if (i >= manifest.len) return error.UnterminatedString;

        return .{
            .start = start,
            .end = i,
        };
    }

    return error.VersionNotFound;
}

fn bumpVersion(alloc: std.mem.Allocator, old: []const u8) ![]u8 {
    var it = std.mem.splitScalar(u8, old, '+');
    const base = it.next() orelse return error.InvalidVersion;
    const build_str = it.next() orelse return error.MissingBuild;
    const build_num = try std.fmt.parseInt(usize, build_str, 10) + 1;

    return std.fmt.allocPrint(alloc, "{s}+{d}", .{ base, build_num });
}
