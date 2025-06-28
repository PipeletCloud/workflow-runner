const builtin = @import("builtin");
const native_os = builtin.os.tag;
const std = @import("std");
const Yaml = @import("yaml").Yaml;
const options = @import("options");
const Config = @import("Config.zig");
const Workflow = @import("Workflow.zig");
const Runner = @import("Runner.zig");
const utils = @import("utils.zig");

pub const std_options: std.Options = .{
    .log_level = if (options.debug) |is_debug| if (is_debug) .debug else .info else std.log.default_level,
};

var debug_allocator: std.heap.DebugAllocator(.{
    .verbose_log = options.debug == true,
}) = .init;

const parseSecretsYaml = @import("yaml.zig").StringHashMap([]const u8);

pub fn main() !void {
    const gpa, const is_debug = gpa: {
        if (native_os == .wasi) break :gpa .{ std.heap.wasm_allocator, false };
        if (options.debug orelse false) break :gpa .{ debug_allocator.allocator(), true };
        break :gpa switch (builtin.mode) {
            .Debug, .ReleaseSafe => .{ debug_allocator.allocator(), true },
            .ReleaseFast, .ReleaseSmall => .{ std.heap.smp_allocator, false },
        };
    };
    defer if (is_debug) {
        _ = debug_allocator.deinit();
    };

    var arena = std.heap.ArenaAllocator.init(gpa);
    defer arena.deinit();

    const alloc = arena.allocator();

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
    defer if (workflow) |*wf| wf.deinit(alloc);

    var secrets = std.StringHashMap([]const u8).init(gpa);
    defer {
        var iter = secrets.iterator();
        while (iter.next()) |entry| {
            gpa.free(entry.key_ptr.*);
            gpa.free(entry.value_ptr.*);
        }
        secrets.deinit();
    }

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.print(
                \\Usage: {s} [options...] FILE
                \\
                \\Options:
                \\  --help, -h     Shows usage
                \\  --config, -c   Specifies the path to the config file
                \\  --once, -o     Run the workflow once
                \\  --secrets, -s  Loads secrets from a specific file
                \\
            , .{
                argv0,
            });
            return;
        } else if (std.mem.startsWith(u8, arg, "--config") or std.mem.eql(u8, arg, "-c")) {
            const value = if (std.mem.indexOf(u8, arg, "=")) |i| arg[(i + 1)..] else args.next() orelse return error.MissingArgument;

            config = utils.importYaml(alloc, Config, value, .{}) catch |err| {
                _ = stderr.print("Failed to open the config file \"{s}\": {}\n", .{ value, err }) catch null;
                return err;
            };
        } else if (std.mem.eql(u8, arg, "--once") or std.mem.eql(u8, arg, "-o")) {
            once = true;
        } else if (std.mem.startsWith(u8, arg, "--secrets") or std.mem.eql(u8, arg, "-s")) {
            const value = if (std.mem.indexOf(u8, arg, "=")) |i| arg[(i + 1)..] else args.next() orelse return error.MissingArgument;

            const source = utils.readFile(gpa, value, .{}) catch |err| {
                _ = stderr.print("Failed to open the secrets file \"{s}\": {}\n", .{ value, err }) catch null;
                return err;
            };
            defer gpa.free(source);

            var yaml: Yaml = .{ .source = source };
            defer yaml.deinit(gpa);

            try yaml.load(gpa);

            secrets.unmanaged = try parseSecretsYaml(yaml, gpa, yaml.docs.items[0]);
        } else if (workflow == null and !std.mem.startsWith(u8, arg, "-")) {
            workflow = utils.importYaml(alloc, Workflow, arg, .{}) catch |err| {
                _ = stderr.print("Failed to open the workflow file \"{s}\": {}\n", .{ arg, err }) catch null;
                return err;
            };
        } else {
            try stderr.print("{s}: unknown argument \"{s}\"\n", .{ argv0, arg });
            return error.UnknownArgument;
        }
    }

    if (workflow == null) {
        workflow = utils.importYaml(alloc, Workflow, "workflow.yaml", .{}) catch |err| {
            _ = stderr.print("Failed to open the default workflow file \"workflow.yaml\": {}\n", .{err}) catch null;
            return err;
        };
    }

    if (secrets.count() == 0) {
        if (utils.readFile(gpa, "secrets.yaml", .{}) catch |err| switch (err) {
            error.FileNotFound => null,
            else => {
                _ = stderr.print("Failed to open the default secrets file \"secrets.yaml\": {}\n", .{err}) catch null;
                return err;
            },
        }) |source| {
            defer gpa.free(source);

            var yaml: Yaml = .{ .source = source };
            defer yaml.deinit(gpa);

            try yaml.load(gpa);

            secrets.unmanaged = try parseSecretsYaml(yaml, gpa, yaml.docs.items[0]);
        }
    }

    var runner = try gpa.create(Runner);
    defer gpa.destroy(runner);

    try runner.init(gpa, &workflow.?);
    defer runner.deinit(gpa);

    while (true) {
        runner.arm();
        try runner.loop.run(.until_done);

        try runner.runGraph(gpa, &config, &workflow.?, &secrets);
        try runner.runWriters(gpa, &config, &workflow.?, &secrets);

        if (once) break;
    }
}
