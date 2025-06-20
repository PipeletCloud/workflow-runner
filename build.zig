const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });

    const module = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{
                .name = "yaml",
                .module = yaml.module("yaml"),
            },
        },
    });

    const exec = b.addExecutable(.{
        .name = "pipelet-workflow-runner",
        .root_module = module,
    });

    b.installArtifact(exec);
}
