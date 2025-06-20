const std = @import("std");
const Self = @This();

pub const Method = enum {
    put,
    post,
};

method: Method,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    _ = self;
    _ = alloc;
}
