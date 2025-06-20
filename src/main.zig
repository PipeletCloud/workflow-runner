const builtin = @import("builtin");
const native_os = builtin.os.tag;
const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Workflow = @import("Workflow.zig");

var debug_allocator: std.heap.DebugAllocator(.{}) = .init;

fn openFile(path: []const u8, flags: std.fs.File.OpenFlags) std.fs.File.OpenError!std.fs.File {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.openFileAbsolute(path, flags);
    }

    return std.fs.cwd().openFile(path, flags);
}

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

    var workflow_file: ?std.fs.File = null;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            try stdout.print(
                \\Usage: {s} [options...] FILE
                \\
                \\Options:
                \\  --help, -h  Shows usage
                \\
            , .{
                argv0,
            });
        } else if (workflow_file == null and !std.mem.startsWith(u8, arg, "-")) {
            workflow_file = try openFile(arg, .{});
        } else {
            try stderr.print("{s}: unknown argument \"{s}\"\n", .{argv0, arg});
            return error.UnknownArgument;
        }
    }

    if (workflow_file == null) {
        workflow_file = openFile("workflow.yaml", .{}) catch |err| {
            _ = stderr.print("Failed to open the default workflow file \"workflow.yaml\": {}\n", .{err}) catch null;
            return err;
        };
    }

    defer if (workflow_file) |wf| wf.close();

    const metadata = try workflow_file.?.metadata();

    const wf_source = try workflow_file.?.reader().readAllAlloc(gpa, metadata.size());
    defer gpa.free(wf_source);

    var yaml: Yaml = .{ .source = wf_source };
    defer yaml.deinit(gpa);

    try yaml.load(gpa);

    var wf = try yaml.parse(gpa, Workflow);
    defer wf.deinit(gpa);

    std.debug.print("{}\n", .{wf});
}
