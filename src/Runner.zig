const std = @import("std");
const xev = @import("xev");
const Workflow = @import("Workflow.zig");
const Self = @This();

loop: xev.Loop,
triggers: []Workflow.Trigger.Runner,

pub fn init(self: *Self, alloc: std.mem.Allocator, wf: *const Workflow) !void {
    const triggers = try alloc.alloc(Workflow.Trigger.Runner, wf.triggers.len);
    errdefer alloc.free(triggers);

    self.loop = try xev.Loop.init(.{});

    for (wf.triggers, triggers) |wt, *t| {
        t.* = try wt.createRunner(alloc, &self.loop);
    }

    self.triggers = triggers;
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    for (self.triggers) |trigger| trigger.deinit(alloc);
    alloc.free(self.triggers);
}
