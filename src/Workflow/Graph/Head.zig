const std = @import("std");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

input: Workflow.Graph.Input,
lines: u64,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
}
