const std = @import("std");

pub fn build(b: *std.Build) void {
    // target & optimize
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // get version from build command (-Dversion=<this>)
    const maybe_version = b.option([]const u8, "version", "What Minecraft version to build (e.g. rd-132211)");
    const version = maybe_version orelse "rd-161348";

    // fullscreen mode
    const options = b.addOptions();
    const fullscreen = b.option(bool, "fullscreen", "Whether fullscreen mode is enabled (rd-160052+)");
    options.addOption(?bool, "fullscreen", fullscreen);

    // glfw import
    const zglfw = b.dependency("zglfw", .{
        .target = target,
        .optimize = optimize,
    });

    // stbi import
    const zstbi = b.dependency("zstbi", .{
        .target = target,
        .optimize = optimize,
    });

    // gl + glu import (headers)
    const GL = b.addTranslateC(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("import.h"),
        .link_libc = true,
    });

    // package minecraft version being run as a module
    const minecraft = b.addModule("minecraft", .{
        .root_source_file = b.path(b.fmt("src/{s}/minecraft.zig", .{version})),
        .target = target,
        .imports = &.{
            .{ .name = "gl", .module = GL.createModule() },
            .{ .name = "glfw", .module = zglfw.module("root") },
            .{ .name = "stbi", .module = zstbi.module("root") },
        },
    });
    minecraft.addOptions("options", options);

    // combine into executable
    const exe = b.addExecutable(.{
        .name = "Minecraft_Zig",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gl", .module = GL.createModule() },
                .{ .name = "glfw", .module = zglfw.module("root") },
                .{ .name = "stbi", .module = zstbi.module("root") },
                .{ .name = "minecraft", .module = minecraft },
            },
        }),
    });

    exe.root_module.linkSystemLibrary("GL", .{});
    exe.root_module.linkSystemLibrary("GLU", .{});

    if (target.result.os.tag != .emscripten) {
        exe.root_module.linkLibrary(zglfw.artifact("glfw"));
    }

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{
        .root_module = minecraft,
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
