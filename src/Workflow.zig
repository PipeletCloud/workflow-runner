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

pub const Graph = union(enum) {
    awk: Awk,
    grep: Grep,
    head: Head,
    sed: Sed,
    tail: Tail,

    pub const Awk = @import("Workflow/Graph/Awk.zig");
    pub const Grep = @import("Workflow/Graph/Grep.zig");
    pub const Head = @import("Workflow/Graph/Head.zig");
    pub const Sed = @import("Workflow/Graph/Sed.zig");
    pub const Tail = @import("Workflow/Graph/Tail.zig");

    pub const Input = union(enum) {
        trigger: []const u8,
        step: *Graph,

        pub fn deinit(self: Input, alloc: std.mem.Allocator) void {
            return switch (self) {
                .trigger => |trigger| alloc.free(trigger),
                .step => |step| step.deinit(alloc),
            };
        }

        pub const parseYaml = @import("yaml.zig").UnionEnum(Input);
    };

    pub fn deinit(self: Graph, alloc: std.mem.Allocator) void {
        return switch (self) {
            .awk => |*awk| @constCast(awk).deinit(alloc),
            .grep => |*grep| @constCast(grep).deinit(alloc),
            .head => |*head| @constCast(head).deinit(alloc),
            .sed => |*sed| @constCast(sed).deinit(alloc),
            .tail => |*tail| @constCast(tail).deinit(alloc),
        };
    }

    pub const parseYaml = @import("yaml.zig").UnionEnum(Graph);
};

name: []const u8,
triggers: ?[]const Trigger = null,
graph: ?[]const Graph = null,

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
}
