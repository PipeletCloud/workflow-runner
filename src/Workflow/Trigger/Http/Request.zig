const std = @import("std");
const Self = @This();

pub const Output = struct {
    body: []const u8,

    pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
        alloc.free(self.body);
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
