const std = @import("std");
const xev = @import("xev");
const Workflow = @import("../../Workflow.zig");
const Cron = @import("../../Cron.zig");
const Self = @This();

pub const Output = struct {
    pub fn get(self: *Output, alloc: std.mem.Allocator, key: []const u8) Workflow.GetOutputError![]const u8 {
        _ = self;
        _ = alloc;
        _ = key;
        return error.InvalidKey;
    }

    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        _ = self;
        _ = alloc;
    }
};

pub const Runner = struct {
    cron: Cron,
    comp: xev.Completion,

    pub fn arm(self: *Runner, loop: *xev.Loop) void {
        loop.timer(&self.comp, self.cron.getFutureTimestamp(), null, Runner.run);
    }

    pub fn deinit(self: *Runner, alloc: std.mem.Allocator) void {
        self.cron.deinit(alloc);
        alloc.destroy(self);
    }

    pub fn run(_: ?*anyopaque, _: *xev.Loop, _: *xev.Completion, _: xev.Result) xev.CallbackAction {
        return .disarm;
    }
};

id: ?[]const u8,
when: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);

    alloc.free(self.when);
}

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator, imap: *Workflow.InputMap) !*Runner {
    _ = imap;

    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);

    runner.* = .{
        .comp = undefined,
        .cron = try Cron.parse(alloc, self.when),
    };
    return runner;
}
