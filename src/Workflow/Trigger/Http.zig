const std = @import("std");
const Self = @This();

method: std.http.Method = .PUT,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    _ = self;
    _ = alloc;
}
