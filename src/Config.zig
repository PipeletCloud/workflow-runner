const std = @import("std");
const Self = @This();

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    _ = self;
    _ = alloc;
}
