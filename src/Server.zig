const std = @import("std");
const xev = @import("xev");
const Client = @import("Server/Client.zig");
const log = std.log.scoped(.server);
const Self = @This();

address: std.net.Address,
server: std.net.Server,
thread: std.Thread,
c_accept: xev.Completion,
clients: std.ArrayList(Client),
resp_mutex: std.Thread.Mutex = .{},
resp: std.StringHashMap(std.AutoHashMapUnmanaged(std.http.Method, std.ArrayListUnmanaged([]const u8))),
loop: xev.Loop,

pub fn init(self: *Self, alloc: std.mem.Allocator, addr: std.net.Address) !void {
    var server = try addr.listen(.{
        .force_nonblocking = true,
    });
    errdefer server.deinit();

    self.* = .{
        .address = addr,
        .server = server,
        .thread = undefined,
        .loop = try .init(.{}),
        .c_accept = .{
            .op = .{ .accept = .{
                .socket = server.stream.handle,
            } },
            .userdata = null,
            .callback = loopAccept,
        },
        .clients = .init(alloc),
        .resp = .init(alloc),
    };

    self.loop.add(&self.c_accept);

    self.thread = try std.Thread.spawn(.{
        .allocator = alloc,
    }, runThread, .{self});
}

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    self.loop.stop();

    const thread = std.Thread.spawn(.{
        .allocator = alloc,
    }, runWakeup, .{self}) catch |err| std.debug.panic("Failed to spawn wakeup thread: {}", .{err});

    self.thread.join();
    thread.join();

    self.clients.deinit();
    self.server.deinit();

    {
        var iter = self.resp.iterator();
        while (iter.next()) |entry| {
            var method_iter = entry.value_ptr.iterator();
            while (method_iter.next()) |method_entry| {
                for (method_entry.value_ptr.items) |i| alloc.free(i);
                method_entry.value_ptr.deinit(alloc);
            }

            entry.value_ptr.deinit(alloc);
        }
    }
    self.resp.deinit();
}

pub fn accept(self: *Self, conn: std.net.Server.Connection) !void {
    const client = try self.clients.addOne();
    errdefer _ = self.clients.pop();

    try client.init(conn, self);
}

pub fn popResponse(self: *Self, target: []const u8, method: std.http.Method) ?[]const u8 {
    self.resp_mutex.lock();
    defer self.resp_mutex.unlock();

    if (self.resp.getPtr(target)) |methods| {
        if (methods.getPtr(method)) |bodies| {
            return bodies.pop();
        }
    }
    return null;
}

pub fn pushResponse(self: *Self, target: []const u8, method: std.http.Method, resp: []const u8) !void {
    self.resp_mutex.lock();
    defer self.resp_mutex.unlock();

    const entry = try self.resp.getOrPutValue(target, .{});
    const method_entry = try entry.value_ptr.getOrPutValue(self.resp.allocator, method, .{});
    try method_entry.value_ptr.append(self.resp.allocator, resp);
}

fn loopAccept(_: ?*anyopaque, _: *xev.Loop, c: *xev.Completion, r: xev.Result) xev.CallbackAction {
    const self: *Self = @fieldParentPtr("c_accept", c);
    if (r.accept) |conn_fd| {
        self.accept(.{
            .stream = .{ .handle = conn_fd },
            .address = .{
                .any = c.op.accept.addr,
            },
        }) catch |err| log.warn("Failed to handle connection {}: {}", .{ conn_fd, err });
        return .rearm;
    } else |err| {
        log.err("Failed to accept: {}", .{err});
        return .disarm;
    }
}

fn runThread(self: *Self) void {
    log.debug("Starting server on {}", .{self.address});
    self.loop.run(.until_done) catch |err| log.err("Failed to run event loop: {}", .{err});
}

fn runWakeup(self: *Self) void {
    const alloc = self.clients.allocator;

    const host_with_port = std.fmt.allocPrint(alloc, "{}", .{self.server.listen_address}) catch |err| {
        log.err("Failed to allocate string: {}", .{err});
        return;
    };
    defer alloc.free(host_with_port);

    const host_port_index = std.mem.lastIndexOf(u8, host_with_port, ":");

    const uri: std.Uri = .{
        .scheme = "http",
        .host = .{ .raw = host_with_port[0..(host_port_index orelse host_with_port.len)] },
        .port = if (host_port_index) |i| std.fmt.parseInt(u16, host_with_port[(i + 1)..], 10) catch |err| {
            log.err("Failed to parse int: {}", .{err});
            return;
        } else null,
    };

    var client: std.http.Client = .{ .allocator = alloc };
    defer client.deinit();

    var server_header_buffer: [1024]u8 = undefined;

    _ = client.fetch(.{
        .method = .GET,
        .location = .{ .uri = uri },
        .server_header_buffer = &server_header_buffer,
    }) catch |err| {
        log.err("Failed to connect to HTTP server: {}", .{err});
        return;
    };
}
