const std = @import("std");
const Self = @This();

pub const Field = union(enum) {
    number: u6,
    any: void,
    set: []const Field,
    range: Range,
    step: Step,

    pub const Range = struct {
        begin: u6,
        end: u6,
    };

    pub const Step = struct {
        value: *Field,
        at: u6,
    };

    pub fn parse(alloc: std.mem.Allocator, str: []const u8) !struct { usize, Field } {
        const i = std.mem.indexOf(u8, str, " ") orelse str.len;
        const slice = str[0..i];

        if (std.mem.eql(u8, slice, "*")) {
            return .{ slice.len, .any };
        } else if (std.mem.lastIndexOf(u8, slice, "/")) |x| {
            const at = try std.fmt.parseInt(u6, slice[x..], 10);

            const value = try alloc.create(Field);
            errdefer alloc.destroy(value);

            value.* = (try Field.parse(alloc, slice[0..at]))[1];

            return .{ slice.len, .{ .step = .{
                .value = value,
                .at = at,
            } } };
        } else if (std.mem.indexOf(u8, slice, "-")) |x| {
            return .{ slice.len, .{ .range = .{
                .begin = try std.fmt.parseInt(u6, slice[0..x], 10),
                .end = try std.fmt.parseInt(u6, slice[x..], 10),
            } } };
        } else if (std.mem.count(u8, slice, ",") > 0) {
            var list = std.ArrayList(Field).init(alloc);
            defer list.deinit();

            var iter = std.mem.splitAny(u8, slice, ",");
            while (iter.next()) |field| {
                try list.append((try Field.parse(alloc, field))[1]);
            }

            return .{ slice.len, .{ .set = try list.toOwnedSlice() } };
        }

        return .{ slice.len, .{ 
            .number = try std.fmt.parseInt(u6, slice, 10),
        } };
    }

    pub fn parseSet(alloc: std.mem.Allocator, str: []const u8) ![]const Field {
        var list = std.ArrayList(Field).init(alloc);
        defer list.deinit();

        var i: usize = 0;
        while (i < str.len) {
            const offset, const field = try Field.parse(alloc, str);
            errdefer field.deinit(alloc);

            try list.append(field);
            i += offset + 1;
        }

        return try list.toOwnedSlice();
    }

    pub fn deinit(self: Field, alloc: std.mem.Allocator) void {
        switch (self) {
            .number, .any, .range => {},
            .set => |set| for (set) |f| f.deinit(alloc),
            .step => |step| step.value.deinit(alloc),
        }
    }
};

minute: Field,
hour: Field,
day: Field,
month: Field,
weekday: Field,

pub fn parse(alloc: std.mem.Allocator, str: []const u8) !Self {
    const list = try Field.parseSet(alloc, str);
    defer alloc.free(list);
    errdefer for (list) |f| f.deinit(alloc);

    if (list.len < 5) return error.TooShort;
    if (list.len > 5) return error.TooLong;

    return .{
        .minute = list[0],
        .hour = list[1],
        .month = list[2],
        .day = list[3],
        .weekday = list[4],
    };
}

pub fn deinit(self: Self, alloc: std.mem.Allocator) void {
    self.minute.deinit(alloc);
    self.hour.deinit(alloc);
    self.day.deinit(alloc);
    self.month.deinit(alloc);
    self.weekday.deinit(alloc);
}

pub fn getFutureTimestamp(self: Self) u64 {
    _ = self;
    @panic("Not yet implemented");
}
