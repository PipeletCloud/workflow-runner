const std = @import("std");
const xev = @import("xev");
const Workflow = @import("../../../Workflow.zig");
const Server = @import("../../../Server.zig");
const Cron = @import("../../../Cron.zig");
const log = std.log.scoped(.@"workflow.trigger.http.response");
const Self = @This();

pub const Output = struct {
    body: []const u8,

    pub fn get(self: *Output, alloc: std.mem.Allocator, key: []const u8) Workflow.GetOutputError![]const u8 {
        if (std.mem.eql(u8, key, "body")) return alloc.dupe(u8, self.body);
        return error.InvalidKey;
    }

    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        alloc.free(self.body);
    }

    pub fn dupe(self: *const Output, alloc: std.mem.Allocator) std.mem.Allocator.Error!Output {
        return .{
            .body = try alloc.dupe(u8, self.body),
        };
    }

    pub fn equal(a: Output, b: Output) bool {
        if (!std.mem.eql(u8, a.body, b.body)) return false;
        return true;
    }
};

pub const Runner = struct {
    allocator: std.mem.Allocator,
    server: *Server,
    endpoint: []const u8,
    method: std.http.Method,
    last_output: ?Output,
    output: ?Output,
    output_ptr: ?*?Workflow.Trigger.Output,
    when_changed: bool,
    delay: Delay,
    comp: xev.Completion,

    pub const Delay = union(enum) {
        cron: Cron,
        value: u64,

        pub fn getFutureTimestamp(self: Delay) u64 {
            return switch (self) {
                .cron => |c| c.getFutureTimestamp(),
                .value => |v| v,
            };
        }
    };

    pub fn arm(self: *Runner, loop: *xev.Loop) void {
        loop.timer(&self.comp, self.delay.getFutureTimestamp(), null, Runner.run);
    }

    pub fn deinit(self: *Runner, alloc: std.mem.Allocator) void {
        if (self.last_output) |*last_output| last_output.deinit(alloc);
        if (self.output) |*output| output.deinit(alloc);

        if (self.delay == .cron) {
            self.delay.cron.deinit(alloc);
        }

        alloc.destroy(self);
    }

    fn fetch(self: *Runner) ?Output {
        if (self.server.popResponse(self.endpoint, self.method)) |resp| {
            return .{
                .body = resp,
            };
        }
        return null;
    }

    fn doRun(self: *Runner) !bool {
        var output = self.fetch() orelse {
            self.output = null;
            if (self.output_ptr) |ptr| ptr.* = null;
            return false;
        };
        log.debug("Received response on {s} as {}: {any}", .{ self.endpoint, self.method, output.body });
        errdefer output.deinit(self.allocator);

        if (self.when_changed) {
            const is_equal = if (self.last_output) |last| last.equal(output) else false;

            self.last_output = self.output;

            if (!is_equal) {
                self.output = output;

                if (self.output_ptr) |ptr| {
                    ptr.* = .{ .http = .{ .response = try output.dupe(self.allocator) } };
                }
                return true;
            }
            return false;
        }

        self.output = output;

        if (self.output_ptr) |ptr| {
            ptr.* = .{ .http = .{ .response = try output.dupe(self.allocator) } };
        }
        return true;
    }

    pub fn run(_: ?*anyopaque, _: *xev.Loop, c: *xev.Completion, _: xev.Result) xev.CallbackAction {
        const self: *Runner = @fieldParentPtr("comp", c);
        return if (self.doRun() catch |e| blk: {
            std.debug.print("Failed to run: {}\n", .{e});
            break :blk false;
        }) .disarm else .rearm;
    }
};

pub const When = union(enum) {
    changed: Changed,
    cron: []const u8,
    delay: u64,

    pub const Changed = union(enum) {
        delay: u64,
        cron: []const u8,

        pub fn deinit(self: Changed, alloc: std.mem.Allocator) void {
            return switch (self) {
                .delay => {},
                .cron => |cron| alloc.free(cron),
            };
        }

        pub fn toDelay(self: Changed, alloc: std.mem.Allocator) !Runner.Delay {
            return switch (self) {
                .delay => |value| .{ .value = value },
                .cron => |str| .{ .cron = try Cron.parse(alloc, str) },
            };
        }

        pub const parseYaml = @import("../../../yaml.zig").UnionEnum(Changed);
    };

    pub fn deinit(self: When, alloc: std.mem.Allocator) void {
        return switch (self) {
            .changed => |*changed| @constCast(changed).deinit(alloc),
            .cron => |cron| alloc.free(cron),
            .delay => {},
        };
    }

    pub fn toDelay(self: When, alloc: std.mem.Allocator) !Runner.Delay {
        return switch (self) {
            .changed => |changed| try changed.toDelay(alloc),
            .cron => |str| .{ .cron = try Cron.parse(alloc, str) },
            .delay => |delay| .{ .value = delay },
        };
    }

    pub const parseYaml = @import("../../../yaml.zig").UnionEnum(When);
};

id: ?[]const u8,
method: std.http.Method,
endpoint: []const u8,
when: ?When,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);

    alloc.free(self.endpoint);

    if (self.when) |when| when.deinit(alloc);
}

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator, imap: *Workflow.InputMap, server: *Server) !*Runner {
    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);

    runner.* = .{
        .allocator = alloc,
        .endpoint = self.endpoint,
        .method = self.method,
        .last_output = null,
        .output = null,
        .output_ptr = if (self.id) |id| (try imap.getOrPutValue(id, null)).value_ptr else null,
        .when_changed = if (self.when) |when| when == .changed else false,
        .delay = if (self.when) |when| try when.toDelay(alloc) else .{ .value = 1000 },
        .server = server,
        .comp = undefined,
    };

    return runner;
}
