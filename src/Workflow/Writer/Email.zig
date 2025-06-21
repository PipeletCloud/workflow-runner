const std = @import("std");
const Self = @This();

address: []const u8,
title: ?[]const u8,
template: []const u8,

pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
    alloc.free(self.address);
    if (self.title) |title| alloc.free(title);
    alloc.free(self.template);
}
