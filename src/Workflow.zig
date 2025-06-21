const std = @import("std");
const xev = @import("xev");
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

    pub const Runner = union(enum) {
        cron: *Cron.Runner,
        http: Http.Runner,

        pub fn deinit(self: Trigger.Runner, alloc: std.mem.Allocator) void {
            return switch (self) {
                .cron => |cron| cron.deinit(alloc),
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

        pub const Runner = union(enum) {
            request: *Request.Runner,
            response: *Response.Runner,

            pub fn deinit(self: Http.Runner, alloc: std.mem.Allocator) void {
                return switch (self) {
                    .request => |req| req.deinit(alloc),
                    .response => |res| res.deinit(alloc),
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

        pub fn createRunner(self: Http, alloc: std.mem.Allocator, loop: *xev.Loop) !Http.Runner {
            return switch (self) {
                .request => |*req| .{ .request = try req.createRunner(alloc, loop) },
                .response => |*res| .{ .response = try res.createRunner(alloc, loop) },
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

    pub fn createRunner(self: Trigger, alloc: std.mem.Allocator, loop: *xev.Loop) !Runner {
        return switch (self) {
            .cron => |*cron| .{ .cron = try cron.createRunner(alloc, loop) },
            .http => |*http| .{ .http = try http.createRunner(alloc, loop) },
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
triggers: []const Trigger,
graph: []const Graph.Toplevel,
writers: []const Writer,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.name);

    for (self.triggers) |trigger| trigger.deinit(alloc);
    alloc.free(self.triggers);

    for (self.graph) |elem| elem.deinit(alloc);
    alloc.free(self.graph);

    for (self.writers) |writer| writer.deinit(alloc);
    alloc.free(self.writers);
}
