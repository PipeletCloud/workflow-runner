const std = @import("std");
const xev = @import("xev");
const Workflow = @import("../../../Workflow.zig");
const Cron = @import("../../../Cron.zig");
const Self = @This();

pub const Output = struct {
    timestamp: i64,
    status: std.http.Status,
    body: []const u8,

    pub fn get(self: *Output, alloc: std.mem.Allocator, key: []const u8) Workflow.GetOutputError![]const u8 {
        if (std.mem.eql(u8, key, "timestamp")) return std.fmt.allocPrint(alloc, "{}", .{self.timestamp});
        if (std.mem.eql(u8, key, "status")) return alloc.dupe(u8, @tagName(self.status));
        if (std.mem.eql(u8, key, "body")) return alloc.dupe(u8, self.body);
        return error.InvalidKey;
    }

    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        alloc.free(self.body);
    }

    pub fn dupe(self: *const Output, alloc: std.mem.Allocator) std.mem.Allocator.Error!Output {
        return .{
            .timestamp = self.timestamp,
            .status = self.status,
            .body = try alloc.dupe(u8, self.body),
        };
    }

    pub fn equal(a: Output, b: Output) bool {
        if (a.status != b.status) return false;
        if (!std.mem.eql(u8, a.body, b.body)) return false;
        return true;
    }
};

pub const Runner = struct {
    uri: std.Uri,
    method: std.http.Method,
    last_output: ?Output,
    output: ?Output,
    output_ptr: ?*?Workflow.Trigger.Output,
    when_changed: bool,
    delay: Delay,
    client: std.http.Client,
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

        self.client.deinit();
        alloc.destroy(self);
    }

    fn fetch(self: *Runner) !Output {
        var resp = std.ArrayList(u8).init(self.client.allocator);
        defer resp.deinit();

        const result = try self.client.fetch(.{
            .location = .{ .uri = self.uri },
            .method = self.method,
            .response_storage = .{ .dynamic = &resp },
        });

        const output = Output{
            .timestamp = std.time.milliTimestamp(),
            .status = result.status,
            .body = try resp.toOwnedSlice(),
        };

        errdefer output.deinit(resp.allocator);
        return output;
    }

    fn doRun(self: *Runner) !bool {
        if (self.when_changed) {
            var output = try self.fetch();
            errdefer output.deinit(self.client.allocator);

            const is_equal = if (self.last_output) |last| last.equal(output) else false;

            self.last_output = self.output;

            if (!is_equal) {
                self.output = output;

                if (self.output_ptr) |ptr| {
                    ptr.* = .{ .http = .{ .request = try output.dupe(self.client.allocator) } };
                }
                return true;
            }

            return false;
        }

        var output = try self.fetch();
        errdefer output.deinit(self.client.allocator);

        self.output = output;

        if (self.output_ptr) |ptr| {
            ptr.* = .{ .http = .{ .request = try output.dupe(self.client.allocator) } };
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
        };
    }

    pub fn toDelay(self: When, alloc: std.mem.Allocator) !Runner.Delay {
        return switch (self) {
            .changed => |changed| try changed.toDelay(alloc),
            .cron => |str| .{ .cron = try Cron.parse(alloc, str) },
        };
    }

    pub const parseYaml = @import("../../../yaml.zig").UnionEnum(When);
};

id: ?[]const u8,
method: ?[]const u8,
url: []const u8,
when: ?When,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.id) |id| alloc.free(id);
    if (self.method) |method| alloc.free(method);

    alloc.free(self.url);

    if (self.when) |when| when.deinit(alloc);
}

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator, imap: *Workflow.InputMap) !*Runner {
    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);

    runner.* = .{
        .uri = try std.Uri.parse(self.url),
        .method = std.meta.stringToEnum(std.http.Method, self.method orelse "GET") orelse return error.InvalidEnum,
        .last_output = null,
        .output = null,
        .output_ptr = if (self.id) |id| (try imap.getOrPutValue(id, null)).value_ptr else null,
        .when_changed = if (self.when) |when| when == .changed else false,
        .delay = if (self.when) |when| try when.toDelay(alloc) else .{ .value = 1000 },
        .client = .{ .allocator = alloc },
        .comp = undefined,
    };

    return runner;
}
