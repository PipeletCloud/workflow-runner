const std = @import("std");
const Workflow = @import("../../../Workflow.zig");
const Self = @This();

input: Workflow.Graph.Input,
expression: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.expression);
}

pub fn run(self: *Self, alloc: std.mem.Allocator, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) ![]const u8 {
    const input = try self.input.get(alloc, inputs, graph);
    defer alloc.free(input);

    var child = std.process.Child.init(&.{"sed", "--", self.expression}, alloc);

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

    const writer = stdin.*.?.writer();
    _ = writer.writeAll(input) catch undefined;
}
