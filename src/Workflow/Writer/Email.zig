const std = @import("std");
const smtp = @import("smtp_client");
const Config = @import("../../Config.zig");
const Workflow = @import("../../Workflow.zig");
const Self = @This();

address: []const u8,
title: ?[]const u8,
template: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    alloc.free(self.address);
    if (self.title) |title| alloc.free(title);
    alloc.free(self.template);
}

pub fn run(self: *Self, alloc: std.mem.Allocator, config: *const Config, imap: *Workflow.InputMap, gmap: *Workflow.GraphMap) !void {
    const config_smtp = config.smtp orelse return error.InvalidConfig;

    const from = if (config_smtp.address) |addr| try alloc.dupe(u8, addr) else try std.fmt.allocPrint(alloc, "{s}@{s}", .{ config_smtp.username orelse "root", config_smtp.host });
    defer alloc.free(from);

    const body = try Workflow.format(alloc, self.template, imap, gmap);
    defer alloc.free(body);

    try smtp.send(.{
        .from = .{ .address = from },
        .to = &.{ .{ .address = self.address } },
        .subject = self.title orelse "Workflow Run",
        .html_body = body,
    }, config_smtp.toSmtpClientConfig(alloc));
}
