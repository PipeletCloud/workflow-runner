const std = @import("std");
const Workflow = @import("../../../Workflow.zig");
const Self = @This();

input: Workflow.Graph.Input,
script: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.script);
}

pub fn run(self: *Self, alloc: std.mem.Allocator, inputs: *Workflow.InputMap) ![]const u8 {
    _ = self;
    _ = alloc;
    _ = inputs;
    return error.NotImplemented;
}
