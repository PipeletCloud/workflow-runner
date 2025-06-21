const std = @import("std");
const Graph = @import("../../Graph.zig");
const Self = @This();

input: Graph.Input,
lines: u64,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
}
