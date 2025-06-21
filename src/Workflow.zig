const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Self = @This();

pub const Trigger = union(enum) {
    cron: Cron,
    http: Http,

    pub const Cron = @import("Workflow/Trigger/Cron.zig");

    pub const Http = union(enum) {
        request: Request,
        response: Response,

        pub const Request = @import("Workflow/Trigger/Http/Request.zig");
        pub const Response = @import("Workflow/Trigger/Http/Response.zig");

        pub fn deinit(self: Http, alloc: std.mem.Allocator) void {
            return switch (self) {
                .request => |*req| @constCast(req).deinit(alloc),
                .response => |*res| @constCast(res).deinit(alloc),
            };
        }

        pub const parseYaml = @import("yaml.zig").UnionEnum(Http);
    };

    pub fn deinit(self: Trigger, alloc: std.mem.Allocator) void {
        return switch (self) {
            .cron => |*cron| @constCast(cron).deinit(alloc),
            .http => |*http| @constCast(http).deinit(alloc),
        };
    }

    pub const parseYaml = @import("yaml.zig").UnionEnum(Trigger);
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
