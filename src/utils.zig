const std = @import("std");
const Yaml = @import("yaml").Yaml;
const Allocator = std.mem.Allocator;

pub fn openFile(path: []const u8, flags: std.fs.File.OpenFlags) std.fs.File.OpenError!std.fs.File {
    if (std.fs.path.isAbsolute(path)) {
        return std.fs.openFileAbsolute(path, flags);
    }

    return std.fs.cwd().openFile(path, flags);
}

pub fn readFile(alloc: Allocator, path: []const u8, flags: std.fs.File.OpenFlags) ![]const u8 {
    var file = try openFile(path, flags);
    defer file.close();

    const metadata = try file.metadata();

    return try file.reader().readAllAlloc(alloc, @intCast(metadata.size()));
}

pub fn importYaml(alloc: Allocator, comptime T: type, path: []const u8, flags: std.fs.File.OpenFlags) !T {
    const source = try readFile(alloc, path, flags);
    defer alloc.free(source);

    var yaml = Yaml{ .source = source };
    defer yaml.deinit(alloc);

    try yaml.load(alloc);

    return try yaml.parse(alloc, T);
}
