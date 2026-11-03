const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const nanoui = b.dependency("nanoui", .{ .target = target, .optimize = optimize }).module("nanoui");
    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "nanoui", .module = nanoui }},
    });
    // The disks' counters come from IOKit.
    const mac = target.result.os.tag == .macos;
    if (mac) mod.linkFramework("IOKit", .{});
    const exe = b.addExecutable(.{ .name = "nanomon", .root_module = mod });
    if (target.result.os.tag == .windows) {
        // Explorer's, the taskbar's and Alt-Tab's icon comes from the exe's own
        // resources; win_frame.zig sets the window's from the same.
        exe.root_module.addWin32ResourceFile(.{ .file = b.path("assets/nanomon.rc") });
        // A window, not a console: double-clicking it opens no terminal, and the
        // log takes what a console would have shown.
        exe.subsystem = .windows;
    }
    b.installArtifact(exe);
    const run = b.addRunArtifact(exe);
    run.addPassthruArgs();
    b.step("run", "Run nanomon").dependOn(&run.step);

    const tests = b.addTest(.{ .root_module = b.createModule(.{
        .root_source_file = b.path("src/tests.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{.{ .name = "nanoui", .module = nanoui }},
    }) });
    if (mac) tests.root_module.linkFramework("IOKit", .{});
    b.step("test", "Run nanomon tests").dependOn(&b.addRunArtifact(tests).step);
    // The tests as a program, for another machine (Linux in a container).
    b.step("test-bin", "Install the tests as zig-out/bin/nanomon-tests").dependOn(&b.addInstallArtifact(tests, .{ .dest_sub_path = "nanomon-tests" }).step);
}
