const std = @import("std");

pub const Step = union(enum) {
    awk: Awk,
    grep: Grep,
    head: Head,
    sed: Sed,
    tail: Tail,

    pub const Awk = @import("Graph/Step/Awk.zig");
    pub const Grep = @import("Graph/Step/Grep.zig");
    pub const Head = @import("Graph/Step/Head.zig");
    pub const Sed = @import("Graph/Step/Sed.zig");
    pub const Tail = @import("Graph/Step/Tail.zig");

    pub fn deinit(self: Step, alloc: std.mem.Allocator) void {
        return switch (self) {
            .awk => |*awk| @constCast(awk).deinit(alloc),
            .grep => |*grep| @constCast(grep).deinit(alloc),
            .head => |*head| @constCast(head).deinit(alloc),
            .sed => |*sed| @constCast(sed).deinit(alloc),
            .tail => |*tail| @constCast(tail).deinit(alloc),
        };
    }

    pub const parseYaml = @import("../yaml.zig").UnionEnum(Step);
};

pub const Toplevel = struct {
    id: ?[]const u8,
    step: Step,

    pub fn deinit(self: Toplevel, alloc: std.mem.Allocator) void {
        if (self.id) |id| alloc.free(id);

        self.step.deinit(alloc);
    }
};

pub const Input = union(enum) {
    trigger: []const u8,
    step: *Step,

    pub fn deinit(self: Input, alloc: std.mem.Allocator) void {
        return switch (self) {
            .trigger => |trigger| alloc.free(trigger),
            .step => |step| step.deinit(alloc),
        };
    }

    pub const parseYaml = @import("../yaml.zig").UnionEnum(Input);
};
