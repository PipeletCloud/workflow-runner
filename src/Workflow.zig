const std = @import("std");
const xev = @import("xev");
const Yaml = @import("yaml").Yaml;
const ztl = @import("ztl");
const Config = @import("Config.zig");
const Server = @import("Server.zig");
const Self = @This();

pub const InputMap = std.StringHashMap(?Trigger.Output);
pub const GraphMap = std.StringHashMap([]const u8);
pub const SecretsMap = std.StringHashMap([]const u8);

pub const GetOutputError = error{
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

        pub fn createRunner(self: Http, alloc: std.mem.Allocator, imap: *InputMap, server: *Server) !Http.Runner {
            return switch (self) {
                .request => |*req| .{ .request = try req.createRunner(alloc, imap, server) },
                .response => |*res| .{ .response = try res.createRunner(alloc, imap, server) },
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

    pub fn createRunner(self: Trigger, alloc: std.mem.Allocator, imap: *InputMap, server: *Server) !Runner {
        return switch (self) {
            .cron => |*cron| .{ .cron = try cron.createRunner(alloc, imap, server) },
            .http => |*http| .{ .http = try http.createRunner(alloc, imap, server) },
        };
    }

    pub const parseYaml = @import("yaml.zig").UnionEnum(Trigger);
};

pub const Graph = @import("Workflow/Graph.zig");

pub const Writer = union(enum) {
    email: Email,
    stdout: Stdout,

    pub const Email = @import("Workflow/Writer/Email.zig");
    pub const Stdout = @import("Workflow/Writer/Stdout.zig");

    pub fn deinit(self: Writer, alloc: std.mem.Allocator) void {
        return switch (self) {
            .email => |*email| @constCast(email).deinit(alloc),
            .stdout => |*stdout| @constCast(stdout).deinit(alloc),
        };
    }

    pub fn run(self: Writer, alloc: std.mem.Allocator, config: *const Config, imap: *InputMap, gmap: *GraphMap, secrets: *SecretsMap, server: *Server) !void {
        return switch (self) {
            .email => |*email| @constCast(email).run(alloc, config, imap, gmap, secrets, server),
            .stdout => |*stdout| @constCast(stdout).run(alloc, config, imap, gmap, secrets, server),
        };
    }

    pub const parseYaml = @import("yaml.zig").UnionEnum(Writer);
};

pub const Formatter = struct {
    config: *const Config,
    imap: *InputMap,
    gmap: *GraphMap,
    secrets: *SecretsMap,
    server: *Server,
    step_inputs: ?[]const Graph.Input,

    pub const ZtlFunctions = struct {
        pub const read_graph = 1;
        pub const read_input = 2;
        pub const read_secret = 1;
    };

    pub fn call(self: *Formatter, vm: *ztl.VM(Formatter), func: ztl.Functions(Formatter), values: []ztl.Value) !ztl.Value {
        return switch (func) {
            .read_graph => vm.createValue(self.gmap.get(values[0].string)),
            .read_input => vm.createValue(blk: {
                if (values[0] == .string) {
                    if (self.imap.get(values[0].string)) |input_opt| {
                        if (input_opt) |input| {
                            break :blk try input.get(vm._allocator, values[1].string);
                        }
                    }
                }

                if (values[0] == .i64) {
                    if (self.step_inputs) |inputs| {
                        const i: usize = @intCast(values[0].i64);
                        if (i >= inputs.len) break :blk null;

                        const input = &inputs[i];
                        break :blk try input.get(vm._allocator, self.config, self.imap, self.gmap, self.secrets, self.server);
                    }
                }
                break :blk null;
            }),
            .read_secret => vm.createValue(self.secrets.get(values[0].string)),
        };
    }
};

name: []const u8,
triggers: []const Trigger,
graph: ?[]const Graph.Toplevel,
writers: []const Writer,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.name);

    for (self.triggers) |trigger| trigger.deinit(alloc);
    alloc.free(self.triggers);

    if (self.graph) |graph| {
        for (graph) |elem| elem.deinit(alloc);
        alloc.free(graph);
    }

    for (self.writers) |writer| writer.deinit(alloc);
    alloc.free(self.writers);
}

pub fn format(
    alloc: std.mem.Allocator,
    src: []const u8,
    config: *const Config,
    imap: *InputMap,
    gmap: *GraphMap,
    secrets: *SecretsMap,
    server: *Server,
    step_inputs: ?[]const Graph.Input,
) ![]const u8 {
    var template = ztl.Template(Formatter).init(alloc, .{
        .config = config,
        .imap = imap,
        .gmap = gmap,
        .secrets = secrets,
        .server = server,
        .step_inputs = step_inputs,
    });
    defer template.deinit();

    try template.compile(src, .{});

    var output = std.ArrayList(u8).init(alloc);
    defer output.deinit();

    try template.render(output.writer(), .{}, .{});
    return try output.toOwnedSlice();
}
