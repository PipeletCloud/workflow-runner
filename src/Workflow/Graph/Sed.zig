const std = @import("std");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

input: Workflow.Graph.Input,
expression: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.expression);
}
