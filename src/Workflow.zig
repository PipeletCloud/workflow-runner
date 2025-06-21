const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Self = @This();

pub const Trigger = union(enum) {
    cron: Cron,
    http: Http,

    pub const Output = union(enum) {
        cron: Cron.Output,
        http: Http.Output,

        pub fn deinit(self: Trigger.Output, alloc: std.mem.Allocator) void {
            return switch (self) {
                .cron => |*cron| @constCast(cron).deinit(alloc),
                .http => |*http| @constCast(http).deinit(alloc),
            };
        }
    };

    pub const Cron = @import("Workflow/Trigger/Cron.zig");

    pub const Http = union(enum) {
        request: Request,
        response: Response,

        pub const Output = union(enum) {
            request: Request.Output,
            response: Response.Output,

            pub fn deinit(self: Http.Output, alloc: std.mem.Allocator) void {
                return switch (self) {
                    .request => |*req| @constCast(req).deinit(alloc),
                    .response => |*res| @constCast(res).deinit(alloc),
                };
            }
        };

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

pub const Graph = @import("Workflow/Graph.zig");

pub const Writer = union(enum) {
    email: Email,

    pub const Email = @import("Workflow/Writer/Email.zig");

    pub fn deinit(self: Writer, alloc: std.mem.Allocator) void {
        return switch (self) {
            .email => |*email| @constCast(email).deinit(alloc),
        };
    }

    pub const parseYaml = @import("yaml.zig").UnionEnum(Writer);
};

name: []const u8,
triggers: ?[]const Trigger = null,
graph: ?[]const Graph.Toplevel = null,
writers: ?[]const Writer = null,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.name);

    if (self.triggers) |triggers| {
        for (triggers) |trigger| trigger.deinit(alloc);
        alloc.free(triggers);
    }

    if (self.graph) |graph| {
        for (graph) |elem| elem.deinit(alloc);
        alloc.free(graph);
    }

    if (self.writers) |writers| {
        for (writers) |writer| writer.deinit(alloc);
        alloc.free(writers);
    }
}
