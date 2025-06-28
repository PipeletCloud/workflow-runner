const std = @import("std");
const xev = @import("xev");
const Server = @import("../Server.zig");
const log = std.log.scoped(.@"server.client");
const Self = @This();

server: *Server,
http_server: std.http.Server,
read_buffer: [1024]u8,
request: std.http.Server.Request,

pub fn init(self: *Self, conn: std.net.Server.Connection, server: *Server) !void {
    const alloc = server.clients.allocator;

    self.* = .{
        .server = server,
        .http_server = .init(conn, &self.read_buffer),
        .read_buffer = undefined,
        .request = undefined,
    };

    self.request = try self.http_server.receiveHead();

    if (std.mem.startsWith(u8, self.request.head.target, "/workflow/request")) {
        try self.request.respond("Not implemented", .{
            .status = .not_found,
        });
    } else if (std.mem.startsWith(u8, self.request.head.target, "/workflow/response")) {
        const target = blk: {
            const tmp = self.request.head.target[18..];
            if (tmp.len == 0) break :blk "/";
            break :blk tmp;
        };

        const reader = try self.request.reader();
        const body = try reader.readAllAlloc(alloc, std.math.maxInt(usize));
        errdefer alloc.free(body);

        log.debug("Received response on {s} as {}: {any}", .{ target, self.request.head.method, body });

        try self.server.pushResponse(target, self.request.head.method, body);

        try self.request.respond("Pushed new response", .{
            .status = .not_found,
        });
    } else {
        const resp = try std.fmt.allocPrint(alloc, "404 - {s} not found", .{self.request.head.target});
        defer alloc.free(resp);

        try self.request.respond(resp, .{
            .status = .not_found,
        });
    }
}
