const std = @import("std");
const xev = @import("xev");
const Workflow = @import("Workflow.zig");
const Self = @This();

loop: xev.Loop,
triggers: []Workflow.Trigger.Runner,
inputs: Workflow.InputMap,

pub fn init(self: *Self, alloc: std.mem.Allocator, wf: *const Workflow) !void {
    const triggers = try alloc.alloc(Workflow.Trigger.Runner, wf.triggers.len);
    errdefer alloc.free(triggers);

    self.loop = try xev.Loop.init(.{});
    errdefer self.loop.deinit();

    self.inputs = Workflow.InputMap.init(alloc);
    errdefer self.inputs.deinit();

    for (wf.triggers, triggers) |wt, *t| {
        t.* = try wt.createRunner(alloc, &self.inputs);
    }

    self.triggers = triggers;
}

pub fn arm(self: *Self) void {
    for (self.triggers) |*t| t.arm(&self.loop);
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    for (self.triggers) |trigger| trigger.deinit(alloc);
    alloc.free(self.triggers);

    var iter = self.inputs.valueIterator();
    while (iter.next()) |op_val| {
        if (op_val.*) |*val| val.deinit(self.inputs.allocator);
    }

    self.inputs.deinit();
    self.loop.deinit();
}
