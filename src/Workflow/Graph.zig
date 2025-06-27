const std = @import("std");
const Config = @import("../Config.zig");
const Workflow = @import("../Workflow.zig");

pub const Step = union(enum) {
    awk: Awk,
    grep: Grep,
    head: Head,
    ollama: Ollama,
    sed: Sed,
    tail: Tail,

    pub const Awk = @import("Graph/Step/Awk.zig");
    pub const Grep = @import("Graph/Step/Grep.zig");
    pub const Head = @import("Graph/Step/Head.zig");
    pub const Ollama = @import("Graph/Step/Ollama.zig");
    pub const Sed = @import("Graph/Step/Sed.zig");
    pub const Tail = @import("Graph/Step/Tail.zig");

    pub fn deinit(self: Step, alloc: std.mem.Allocator) void {
        return switch (self) {
            .awk => |*awk| @constCast(awk).deinit(alloc),
            .grep => |*grep| @constCast(grep).deinit(alloc),
            .head => |*head| @constCast(head).deinit(alloc),
            .ollama => |*ollama| @constCast(ollama).deinit(alloc),
            .sed => |*sed| @constCast(sed).deinit(alloc),
            .tail => |*tail| @constCast(tail).deinit(alloc),
        };
    }

    pub fn run(self: Step, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) anyerror![]const u8 {
        return switch (self) {
            .awk => |*awk| @constCast(awk).run(alloc, config, inputs, graph),
            .grep => |*grep| @constCast(grep).run(alloc, config, inputs, graph),
            .head => |*head| @constCast(head).run(alloc, config, inputs, graph),
            .ollama => |*ollama| @constCast(ollama).run(alloc, config, inputs, graph),
            .sed => |*sed| @constCast(sed).run(alloc, config, inputs, graph),
            .tail => |*tail| @constCast(tail).run(alloc, config, inputs, graph),
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
    trigger: Trigger,
    step: *Step,
    ref_step: []const u8,

    pub const Trigger = struct {
        id: []const u8,
        key: []const u8,

        pub fn deinit(self: Trigger, alloc: std.mem.Allocator) void {
            alloc.free(self.id);
            alloc.free(self.key);
        }
    };

    pub fn get(self: Input, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) ![]const u8 {
        return switch (self) {
            .trigger => |trigger| ((inputs.get(trigger.id) orelse return error.InvalidId) orelse return error.TriggerMissingOutput).get(alloc, trigger.key),
            .step => |step| step.run(alloc, config, inputs, graph),
            .ref_step => |ref_step| alloc.dupe(u8, graph.get(ref_step) orelse return error.GraphMissingOutput),
        };
    }

    pub fn deinit(self: Input, alloc: std.mem.Allocator) void {
        return switch (self) {
            .trigger => |trigger| trigger.deinit(alloc),
            .step => |step| step.deinit(alloc),
            .ref_step => |ref_step| alloc.free(ref_step),
        };
    }

    pub const parseYaml = @import("../yaml.zig").UnionEnum(Input);
};
