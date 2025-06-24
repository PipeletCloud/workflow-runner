const builtin = @import("builtin");
const native_os = builtin.os.tag;
const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Config = @import("Config.zig");
const Workflow = @import("Workflow.zig");
const Runner = @import("Runner.zig");
const utils = @import("utils.zig");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var args = try std.process.argsWithAllocator(gpa);
    defer args.deinit();

    const argv0 = args.next() orelse undefined;

    const raw_stdout = std.io.getStdOut().writer();
    var buffered_stdout = std.io.bufferedWriter(raw_stdout);
    defer _ = buffered_stdout.flush() catch null;

    const stdout = buffered_stdout.writer();

    const raw_stderr = std.io.getStdErr().writer();
    var buffered_stderr = std.io.bufferedWriter(raw_stderr);
    defer _ = buffered_stderr.flush() catch null;

    const stderr = buffered_stderr.writer();

    var once = false;

    var config: Config = .{};
    defer config.deinit(gpa);

    var workflow: ?Workflow = null;
    defer if (workflow) |*wf| wf.deinit(gpa);

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.print(
                \\Usage: {s} [options...] FILE
                \\
                \\Options:
                \\  --help, -h    Shows usage
                \\  --config, -c  Specifies the path to the config file
                \\  --once, -o    Run the workflow once
                \\
            , .{
                argv0,
            });
            return;
        } else if (std.mem.startsWith(u8, arg, "--config") or std.mem.eql(u8, arg, "-c")) {
            const value = if (std.mem.indexOf(u8, arg, "=")) |i| arg[(i + 1)..] else args.next() orelse return error.MissingArgument;

            config = utils.importYaml(gpa, Config, value, .{}) catch |err| {
                _ = stderr.print("Failed to open the config file \"{s}\": {}\n", .{value, err}) catch null;
                return err;
            };
        } else if (std.mem.eql(u8, arg, "--once") or std.mem.eql(u8, arg, "-o")) {
            once = true;
        } else if (workflow == null and !std.mem.startsWith(u8, arg, "-")) {
            workflow = utils.importYaml(gpa, Workflow, arg, .{}) catch |err| {
                _ = stderr.print("Failed to open the workflow file \"{s}\": {}\n", .{arg, err}) catch null;
                return err;
            };
        } else {
            try stderr.print("{s}: unknown argument \"{s}\"\n", .{argv0, arg});
            return error.UnknownArgument;
        }
    }

    if (workflow == null) {
        workflow = utils.importYaml(gpa, Workflow, "workflow.yaml", .{}) catch |err| {
            _ = stderr.print("Failed to open the default workflow file \"workflow.yaml\": {}\n", .{err}) catch null;
            return err;
        };
    }

    var runner = try gpa.create(Runner);
    defer gpa.destroy(runner);

    try runner.init(gpa, &workflow.?);
    defer runner.deinit(gpa);

    while (true) {
        runner.arm();
        try runner.loop.run(.until_done);

        try runner.runGraph(gpa, &workflow.?);
        try runner.runWriters(gpa, &config, &workflow.?);

        if (once) break;
    }
}
