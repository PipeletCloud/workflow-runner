const std = @import("std");
const xev = @import("xev");
const Workflow = @import("../../../Workflow.zig");
const Self = @This();

pub const Output = struct {
    target: []const u8,
    body: []const u8,

    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        alloc.free(self.target);
        alloc.free(self.body);
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

pub const When = union(enum) {
    changed: Changed,
    cron: []const u8,
    requested: struct {},

    pub const Changed = union(enum) {
        delay: u64,
        cron: []const u8,

        pub fn deinit(self: Changed, alloc: std.mem.Allocator) void {
            return switch (self) {
                .delay => {},
                .cron => |cron| alloc.free(cron),
            };
        }

        pub const parseYaml = @import("../../../yaml.zig").UnionEnum(Changed);
    };

    pub fn deinit(self: When, alloc: std.mem.Allocator) void {
        return switch (self) {
            .changed => |*changed| @constCast(changed).deinit(alloc),
            .cron => |cron| alloc.free(cron),
            .requested => {},
        };
    }

    pub const parseYaml = @import("../../../yaml.zig").UnionEnum(When);
};

id: ?[]const u8,
method: ?[]const u8,
endpoint: []const u8,
when: ?When,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);
    if (self.method) |method| alloc.free(method);

    alloc.free(self.endpoint);

    if (self.when) |when| when.deinit(alloc);
}

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator, imap: *Workflow.InputMap) !*Runner {
    _ = self;
    _ = imap;

    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);
    return runner;
}
