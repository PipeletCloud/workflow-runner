const std = @import("std");
const Self = @This();

when: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.when);
}
