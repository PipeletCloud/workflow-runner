const std = @import("std");
const xev = @import("xev");
const Yaml = @import("yaml").Yaml;
const Self = @This();

pub const InputMap = std.StringHashMap(?Trigger.Output);
pub const GraphMap = std.StringHashMap([]const u8);

pub const GetOutputError = error {
    InvalidKey,
} || std.mem.Allocator.Error;

pub const Trigger = union(enum) {
    cron: Cron,
    http: Http,

    pub const Output = union(enum) {
        cron: Cron.Output,
        http: Http.Output,

        pub fn get(self: Trigger.Output, alloc: std.mem.Allocator, key: []const u8) GetOutputError![]const u8 {
            return switch (self) {
                .cron => |*cron| @constCast(cron).get(alloc, key),
                .http => |*http| @constCast(http).get(alloc, key),
            };
        }

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

        pub fn arm(self: Trigger.Runner, loop: *xev.Loop) void {
            return switch (self) {
                .cron => |cron| cron.arm(loop),
                .http => |*http| @constCast(http).arm(loop),
            };
        }

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

            pub fn get(self: Http.Output, alloc: std.mem.Allocator, key: []const u8) GetOutputError![]const u8 {
                return switch (self) {
                    .request => |*req| @constCast(req).get(alloc, key),
                    .response => |*res| @constCast(res).get(alloc, key),
                };
            }

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

            pub fn arm(self: Http.Runner, loop: *xev.Loop) void {
                return switch (self) {
                    .request => |req| req.arm(loop),
                    .response => |res| res.arm(loop),
                };
            }

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

        pub fn createRunner(self: Http, alloc: std.mem.Allocator, imap: *InputMap) !Http.Runner {
            return switch (self) {
                .request => |*req| .{ .request = try req.createRunner(alloc, imap) },
                .response => |*res| .{ .response = try res.createRunner(alloc, imap) },
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

    pub fn createRunner(self: Trigger, alloc: std.mem.Allocator, imap: *InputMap) !Runner {
        return switch (self) {
            .cron => |*cron| .{ .cron = try cron.createRunner(alloc, imap) },
            .http => |*http| .{ .http = try http.createRunner(alloc, imap) },
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
