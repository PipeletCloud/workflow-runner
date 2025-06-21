const std = @import("std");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

input: Workflow.Graph.Input,
before: ?usize,
after: ?usize,
inverse: bool,
case_ignore: bool,
expression: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.expression);
}
