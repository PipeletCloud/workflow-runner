const std = @import("std");
const Config = @import("../../../Config.zig");
const Workflow = @import("../../../Workflow.zig");
const log = std.log.scoped(.@"workflow.graph.step.sed");
const Self = @This();

input: Workflow.Graph.Input,
expression: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.expression);
}

pub fn run(
    self: *Self,
    alloc: std.mem.Allocator,
    config: *const Config,
    inputs: *Workflow.InputMap,
    graph: *Workflow.GraphMap,
    secrets: *Workflow.SecretsMap,
) ![]const u8 {
    const input = try self.input.get(alloc, config, inputs, graph, secrets);
    defer alloc.free(input);

    log.debug("Running \"sed -- {s}\"", .{self.expression});
    var child = std.process.Child.init(&.{ "sed", "--", self.expression }, alloc);

    child.stdin_behavior = .Pipe;
    child.stderr_behavior = .Pipe;
    child.stdout_behavior = .Pipe;

    try child.spawn();

    var stdout: std.ArrayListUnmanaged(u8) = .empty;
    errdefer stdout.deinit(alloc);

    var stderr: std.ArrayListUnmanaged(u8) = .empty;
    errdefer stderr.deinit(alloc);

    const thread = try std.Thread.spawn(.{
        .allocator = alloc,
    }, runThread, .{ &child.stdin, input });

    try child.collectOutput(alloc, &stdout, &stderr, std.math.maxInt(u64));

    const term = try child.wait();
    thread.join();

    if (term != .Exited) return error.UnexpectedFailure;

    return try stdout.toOwnedSlice(alloc);
}

fn runThread(stdin: *?std.fs.File, input: []const u8) void {
    defer {
        stdin.*.?.close();
        stdin.* = null;
    }

    log.debug("Feeding {any} to process", .{input});

    const writer = stdin.*.?.writer();
    _ = writer.writeAll(input) catch undefined;
}
