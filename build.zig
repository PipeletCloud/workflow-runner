const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const yaml = b.dependency("yaml", .{
        .target = target,
        .optimize = optimize,
    });

    const libxev = b.dependency("libxev", .{
        .target = target,
        .optimize = optimize,
    });

    const smtp_client = b.dependency("smtp_client", .{
        .target = target,
        .optimize = optimize,
    });

    const ztl = b.dependency("ztl", .{
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
            .{
                .name = "xev",
                .module = libxev.module("xev"),
            },
            .{
                .name = "smtp_client",
                .module = smtp_client.module("smtp_client"),
            },
            .{
                .name = "ztl",
                .module = ztl.module("ztl"),
            },
        },
    });

    const exec = b.addExecutable(.{
        .name = "pipelet-workflow-runner",
        .root_module = module,
    });

    b.installArtifact(exec);
}
