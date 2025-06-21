const std = @import("std");
const Self = @This();

pub const Output = struct {};

id: ?[]const u8,
when: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);

    alloc.free(self.when);
}
