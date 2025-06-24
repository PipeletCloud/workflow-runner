const std = @import("std");
const smtp_client = @import("smtp_client");
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

smtp: ?Smtp = null,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.smtp) |*s| s.deinit(alloc);
}
