const std = @import("std");
const xev = @import("xev");
const Config = @import("Config.zig");
const Workflow = @import("Workflow.zig");
const Server = @import("Server.zig");
const Self = @This();

loop: xev.Loop,
triggers: []Workflow.Trigger.Runner,
inputs: Workflow.InputMap,
graph: Workflow.GraphMap,

pub fn init(self: *Self, alloc: std.mem.Allocator, wf: *const Workflow, server: *Server) !void {
    const triggers = try alloc.alloc(Workflow.Trigger.Runner, wf.triggers.len);
    errdefer alloc.free(triggers);

    self.loop = try xev.Loop.init(.{});
    errdefer self.loop.deinit();

    self.inputs = Workflow.InputMap.init(alloc);
    errdefer self.inputs.deinit();

    self.graph = Workflow.GraphMap.init(alloc);
    errdefer self.graph.deinit();

    for (wf.triggers, triggers) |wt, *t| {
        t.* = try wt.createRunner(alloc, &self.inputs, server);
    }

    self.triggers = triggers;
}

pub fn arm(self: *Self) void {
    for (self.triggers) |*t| t.arm(&self.loop);
}

pub fn runGraph(self: *Self, alloc: std.mem.Allocator, config: *const Config, wf: *const Workflow, secrets: *Workflow.SecretsMap, server: *Server) !void {
    if (wf.graph) |graph| {
        for (graph, 0..) |g, i| {
            const id = if (g.id) |id| try alloc.dupe(u8, id) else try std.fmt.allocPrint(alloc, "{}", .{i});
            errdefer alloc.free(id);

            const result = try g.step.run(alloc, config, &self.inputs, &self.graph, secrets, server);
            errdefer alloc.free(result);

            try self.graph.put(id, result);
        }
    }
}

pub fn runWriters(self: *Self, alloc: std.mem.Allocator, config: *const Config, wf: *const Workflow, secrets: *Workflow.SecretsMap, server: *Server) !void {
    for (wf.writers) |w| {
        try w.run(alloc, config, &self.inputs, &self.graph, secrets, server);
    }
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    for (self.triggers) |trigger| trigger.deinit(alloc);
    alloc.free(self.triggers);

    {
        var iter = self.inputs.valueIterator();
        while (iter.next()) |op_val| {
            if (op_val.*) |*val| val.deinit(self.inputs.allocator);
        }
    }

    {
        var iter = self.graph.iterator();
        while (iter.next()) |entry| {
            alloc.free(entry.key_ptr.*);
            alloc.free(entry.value_ptr.*);
        }
    }

    self.inputs.deinit();
    self.graph.deinit();
    self.loop.deinit();
}
