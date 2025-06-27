const std = @import("std");
const Config = @import("../../../Config.zig");
const Workflow = @import("../../../Workflow.zig");
const Ollama = @import("ollama").Ollama;
const Self = @This();

model: ?[]const u8,
prompt: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.model) |model| alloc.free(model);
    alloc.free(self.prompt);
}

pub fn run(self: *Self, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const prompt = try Workflow.format(alloc, self.prompt, inputs, graph);
    defer alloc.free(prompt);

    const model = (if (config.ollama) |ollama| ollama.default_model else self.model) orelse "llama3.2";

    var ollama: Ollama = if (config.ollama) |ollama| ollama.toOllama(arena.allocator()) else .{ .allocator = arena.allocator() };
    defer ollama.deinit();

    var result = std.ArrayList(u8).init(alloc);
    defer result.deinit();

    const responses = try ollama.generate(.{
        .model = model,
        .prompt = prompt,
    });

    while (try responses.next()) |resp| {
        try result.appendSlice(resp.response);
    }

    return try result.toOwnedSlice();
}
