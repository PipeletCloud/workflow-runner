const std = @import("std");
const Yaml = @import("yaml").Yaml;

fn parseValue(yaml: Yaml, alloc: std.mem.Allocator, comptime T: type, value: Yaml.Value) Yaml.Error!T {
    const info = @typeInfo(T);
    if (info == .pointer) {
        if (info.pointer.size == .one) {
            const v = try alloc.create(info.pointer.child);
            v.* = try parseValue(yaml, alloc, info.pointer.child, value);
            return v;
        }
    }
    return yaml.parseValue(alloc, T, value);
}

pub fn UnionEnum(comptime T: type) fn (Yaml, std.mem.Allocator, Yaml.Value) Yaml.Error!T {
    return (struct {
        fn parseYaml(yaml: Yaml, alloc: std.mem.Allocator, value: Yaml.Value) Yaml.Error!T {
            const map = try value.asMap();

            inline for (@typeInfo(T).@"union".fields) |field| {
                if (map.get(field.name)) |entry| {
                    return @unionInit(T, field.name, try parseValue(yaml, alloc, field.type, entry));
                }
            }

            return error.TypeMismatch;
        }
    }).parseYaml;
}

pub fn StringHashMap(comptime T: type) fn (Yaml, std.mem.Allocator, Yaml.Value) Yaml.Error!std.StringHashMapUnmanaged(T) {
    return (struct {
        fn parseYaml(yaml: Yaml, alloc: std.mem.Allocator, value: Yaml.Value) Yaml.Error!std.StringHashMapUnmanaged(T) {
            const map = try value.asMap();

            var hash_map: std.StringHashMapUnmanaged(T) = .empty;
            errdefer hash_map.deinit(alloc);

            var iter = map.iterator();
            while (iter.next()) |entry| {
                const key = try alloc.dupe(u8, entry.key_ptr.*);
                errdefer alloc.free(key);

                try hash_map.put(alloc, key, try parseValue(yaml, alloc, T, entry.value_ptr.*));
            }

            return hash_map;
        }
    }).parseYaml;
}
