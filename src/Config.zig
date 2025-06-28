const std = @import("std");
const smtp_client = @import("smtp_client");
const OllamaClient = @import("ollama").Ollama;
const Self = @This();

pub const Smtp = struct {
    port: ?u16,
    host: []const u8,
    timeout: ?i32,
    encryption: ?smtp_client.Encryption,
    username: ?[]const u8 = null,
    password: ?[]const u8 = null,
    local_name: ?[]const u8,
    message_id_host: ?[]const u8 = null,
    address: ?[]const u8 = null,

    pub fn deinit(self: *Smtp, alloc: std.mem.Allocator) void {
        alloc.free(self.host);

        if (self.username) |username| alloc.free(username);
        if (self.password) |password| alloc.free(password);
        if (self.local_name) |local_name| alloc.free(local_name);
        if (self.message_id_host) |message_id_host| alloc.free(message_id_host);
        if (self.address) |address| alloc.free(address);
    }

    pub fn toSmtpClientConfig(self: *const Smtp, alloc: std.mem.Allocator) smtp_client.Config {
        return .{
            .port = self.port orelse 25,
            .host = self.host,
            .timeout = self.timeout orelse 10_000,
            .encryption = self.encryption orelse .tls,
            .username = self.username,
            .password = self.password,
            .local_name = self.local_name orelse "localhost",
            .message_id_host = self.message_id_host,
            .allocator = alloc,
        };
    }
};

pub const Ollama = struct {
    schema: ?[]const u8,
    host: ?[]const u8,
    port: ?u16,
    default_model: ?[]const u8,

    pub fn deinit(self: *Ollama, alloc: std.mem.Allocator) void {
        if (self.schema) |schema| alloc.free(schema);
        if (self.host) |host| alloc.free(host);
        if (self.default_model) |default_model| alloc.free(default_model);
    }

    pub fn toOllama(self: *const Ollama, alloc: std.mem.Allocator) OllamaClient {
        return .{
            .allocator = alloc,
            .schema = self.schema orelse "http",
            .host = self.host orelse "localhost",
            .port = self.port orelse 11434,
        };
    }
};

pub const HttpServer = struct {
    address: ?[]const u8,

    pub fn deinit(self: *HttpServer, alloc: std.mem.Allocator) void {
        _ = self;
        _ = alloc;
        // FIXME: invalid free
        //if (self.address) |addr| alloc.free(addr);
    }

    pub fn getAddress(self: *const HttpServer) !std.net.Address {
        const addr = self.address orelse "localhost:8080";

        if (std.mem.startsWith(u8, addr, "unix:")) {
            const path = addr[5..];
            return .initUnix(path);
        }

        const split = std.mem.lastIndexOf(u8, addr, ":") orelse addr.len;

        const name = blk: {
            if (split == addr.len) break :blk addr;
            break :blk addr[0..split];
        };

        const port: u16 = blk: {
            if (split == addr.len) break :blk 8080;
            break :blk try std.fmt.parseInt(u16, addr[(split + 1)..], 10);
        };

        return .parseIp(name, port);
    }
};

smtp: ?Smtp = null,
ollama: ?Ollama = null,
http_server: ?HttpServer = null,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.smtp) |*s| s.deinit(alloc);
    if (self.ollama) |*ollama| ollama.deinit(alloc);
    if (self.http_server) |*h| h.deinit(alloc);
}
