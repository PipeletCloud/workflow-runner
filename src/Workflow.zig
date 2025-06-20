const std = @import("std");
const Self = @This();

pub const Trigger = union(enum) {
    cron: Cron,
    http: Http,

    pub const Cron = @import("Workflow/Trigger/Cron.zig");
    pub const Http = @import("Workflow/Trigger/Http.zig");

    pub fn deinit(self: Trigger, alloc: std.mem.Allocator) void {
        return switch (self) {
            .cron => |*cron| @constCast(cron).deinit(alloc),
            .http => |*http| @constCast(http).deinit(alloc),
        };
    }
};

name: []const u8,
triggers: ?[]const Trigger = null,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.name);
    if (self.triggers) |triggers| {
        for (triggers) |trigger| trigger.deinit(alloc);
        alloc.free(triggers);
    }
}
