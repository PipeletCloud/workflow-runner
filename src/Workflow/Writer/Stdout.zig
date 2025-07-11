const std = @import("std");
const Config = @import("../../Config.zig");
const Server = @import("../../Server.zig");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

template: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.template);
}

pub fn run(
    self: *Self,
    alloc: std.mem.Allocator,
    config: *const Config,
    imap: *Workflow.InputMap,
    gmap: *Workflow.GraphMap,
    secrets: *Workflow.SecretsMap,
    server: *Server,
) !void {
    const body = try Workflow.format(alloc, self.template, config, imap, gmap, secrets, server, null);
    defer alloc.free(body);

    const stdout = std.io.getStdOut().writer();
    try stdout.writeAll(body);
    try stdout.writeByte('\n');
}
