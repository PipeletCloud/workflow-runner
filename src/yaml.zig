const std = @import("std");
const Yaml = @import("yaml").Yaml;

pub fn UnionEnum(comptime T: type) fn (Yaml, std.mem.Allocator, Yaml.Value) Yaml.Error!T {
    return (struct {
        fn parseYaml(yaml: Yaml, alloc: std.mem.Allocator, value: Yaml.Value) Yaml.Error!T {
            const map = try value.asMap();

            inline for (@typeInfo(T).@"union".fields) |field| {
                if (map.get(field.name)) |entry| {
                    return @unionInit(T, field.name, try yaml.parseValue(alloc, field.type, entry));
                }
            }

            return error.TypeMismatch;
        }
    }).parseYaml;
}
