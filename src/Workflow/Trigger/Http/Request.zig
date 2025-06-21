const std = @import("std");
const xev = @import("xev");
const Self = @This();

pub const Output = struct {
    timestamp: i64,
    status: std.http.Status,
    body: []const u8,

    pub fn deinit(self: *Output, alloc: std.mem.Allocator) void {
        alloc.free(self.body);
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
    when_changed: bool,
    client: std.http.Client,
    comp: xev.Completion,

    pub fn arm(self: *Runner, loop: *xev.Loop) void {
        // TODO: replace 10 with a value computed based on "when"
        loop.timer(&self.comp, 10, null, Runner.run);
    }

    pub fn deinit(self: *Runner, alloc: std.mem.Allocator) void {
        if (self.last_output) |*last_output| last_output.deinit(alloc);
        if (self.output) |*output| output.deinit(alloc);

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
            const output = try self.fetch();
            errdefer output.deinit(self.client.allocator);

            const is_equal = if (self.last_output) |last| last.equal(output) else false;

            self.last_output = self.output;

            if (!is_equal) {
                self.output = output;
                return true;
            }
        }

        return false;
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

        pub const parseYaml = @import("../../../yaml.zig").UnionEnum(Changed);
    };

    pub fn deinit(self: When, alloc: std.mem.Allocator) void {
        return switch (self) {
            .changed => |*changed| @constCast(changed).deinit(alloc),
            .cron => |cron| alloc.free(cron),
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

pub fn createRunner(self: *const Self, alloc: std.mem.Allocator) !*Runner {
    const runner = try alloc.create(Runner);
    errdefer alloc.destroy(runner);

    runner.* = .{
        .uri = try std.Uri.parse(self.url),
        .method = std.meta.stringToEnum(std.http.Method, self.method orelse "GET") orelse return error.InvalidEnum,
        .last_output = null,
        .output = null,
        .when_changed = if (self.when) |when| when == .changed else false,
        .client = .{ .allocator = alloc },
        .comp = undefined,
    };

    return runner;
}
