const std = @import("std");
const xev = @import("xev");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

pub const Output = struct {
    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        _ = self;
        _ = alloc;
    }
};

pub const Runner = struct {
    pub fn arm(self: *Runner, loop: *xev.Loop) void {
        _ = self;
        _ = loop;
    }

    pub fn deinit(self: *Runner, alloc: std.mem.Allocator) void {
        alloc.destroy(self);
    }
};

id: ?[]const u8,
when: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);

    alloc.free(self.when);
}

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator, imap: *Workflow.InputMap) !*Runner {
    _ = self;
    _ = imap;

    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);
    return runner;
}
