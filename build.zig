const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Library
    const lib_mod = b.addModule("libchroma", .{
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });

    const semver = try incrementBuildNumber(b);

    // Static and dynamic library defs
    const staticLib = b.addLibrary(.{
        .name = "chroma",
        .linkage = .static,
        .root_module = lib_mod,
        .version = semver,
    });
    const dynLib = b.addLibrary(.{
        .name = "chroma",
        .linkage = .dynamic,
        .root_module = lib_mod,
        .version = semver,
    });
    b.installArtifact(staticLib);
    b.installArtifact(dynLib);
    b.installDirectory(.{
        .source_dir = b.path("include"),
        .install_dir = .header,
        .install_subdir = "",
    });

    // Build lib step
    const lib_step = b.step("lib", "Build only the library (static + dynamic)");
    lib_step.dependOn(&staticLib.step);
    lib_step.dependOn(&dynLib.step);
    // Lib tests
    const lib_tests = b.addTest(.{
        .root_module = lib_mod,
    });
    // Translate chroma.h so the C ABI (chroma_c.zig) can use it in tests.
    const translate_c = b.addTranslateC(.{
        .root_source_file = b.path("include/chroma.h"),
        .target = target,
        .optimize = optimize,
    });
    lib_tests.root_module.addImport("chroma_h", translate_c.createModule());
    const run_lib_tests = b.addRunArtifact(lib_tests);

    // CLI executable
    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/cli/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("libchroma", lib_mod);
    const exe = b.addExecutable(.{
        .name = "chroma",
        .root_module = exe_mod,
    });
    b.installArtifact(exe);

    // Build CLI step
    const cli_step = b.step("cli", "Build only the CLI executable");
    cli_step.dependOn(&exe.step);
    // CLI tests
    const exe_tests = b.addTest(.{
        .root_module = exe_mod,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    // Run exe step
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the CLI");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const TestType = enum { lib, exe };
    const test_type = b.option(TestType, "test", "Test module (leave blank for all)");
    const test_step = b.step("test", "Run tests (-Dscope lib|exe)");
    if (test_type == null or test_type.? == TestType.lib)
        test_step.dependOn(&run_lib_tests.step);
    if (test_type == null or test_type.? == TestType.exe)
        test_step.dependOn(&run_exe_tests.step);

    // Nuke step
    const nuke_step = b.step("nuke", "Remove all build artifacts and cache");
    nuke_step.dependOn(&b.addRemoveDirTree(b.path(".zig-cache")).step);
    nuke_step.dependOn(&b.addRemoveDirTree(b.path("zig-out")).step);

    const check_step = b.step("check", "Check if libchroma compiles");
    check_step.dependOn(&exe.step);
    check_step.dependOn(&staticLib.step);
    check_step.dependOn(&dynLib.step);
    check_step.dependOn(&run_lib_tests.step);
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
    const build_str = it.next() orelse "0";
    const build_num = try std.fmt.parseInt(usize, build_str, 10) + 1;

    return std.fmt.allocPrint(alloc, "{s}+{d}", .{ base, build_num });
}
