const std = @import("std");
const Graph = @import("../../Graph.zig");
const Self = @This();

input: Graph.Input,
script: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.input.deinit(alloc);
    alloc.free(self.script);
}
