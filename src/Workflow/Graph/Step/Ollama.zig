const std = @import("std");
const Config = @import("../../../Config.zig");
const Workflow = @import("../../../Workflow.zig");
const ollama = @import("ollama");
const Self = @This();

pub const Image = struct {
    source: Source,
    kind: ?Kind,

    pub const Source = union(enum) {
        input: Workflow.Graph.Input,
        value: []const u8,

        pub fn get(self: Source, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) ![]const u8 {
            return switch (self) {
                .input => |*input| input.get(alloc, config, inputs, graph),
                .value => |value| alloc.dupe(u8, value),
            };
        }

        pub fn deinit(self: Source, alloc: std.mem.Allocator) void {
            return switch (self) {
                .input => |*input| input.deinit(alloc),
                .value => |value| alloc.free(value),
            };
        }
    };

    pub const Kind = enum {
        bytes,
        base64,
    };

    pub fn toOllama(self: Image, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) !ollama.types.Image {
        const source = try self.source.get(alloc, config, inputs, graph);
        const kind = self.kind orelse .bytes;
        if (kind == .base64) return source;

        defer alloc.free(source);

        const codec = std.base64.standard;
        var encoded = std.ArrayList(u8).init(alloc);
        defer encoded.deinit();

        try codec.Encoder.encodeWriter(encoded.writer(), source);
        return try encoded.toOwnedSlice();
    }

    pub fn deinit(self: Image, alloc: std.mem.Allocator) void {
        self.source.deinit(alloc);
    }
};

inputs: ?[]const Workflow.Graph.Input,
images: ?[]const Image,
model: ?[]const u8,
prompt: []const u8,

pub fn deinit(self: *Self, alloc: std.mem.Allocator) void {
    if (self.inputs) |inputs| {
        for (inputs) |input| input.deinit(alloc);
        alloc.free(inputs);
    }

    if (self.images) |images| {
        for (images) |image| image.deinit(alloc);
    }

    if (self.model) |model| alloc.free(model);
    alloc.free(self.prompt);
}

pub fn run(self: *Self, alloc: std.mem.Allocator, config: *const Config, inputs: *Workflow.InputMap, graph: *Workflow.GraphMap) ![]const u8 {
    var arena = std.heap.ArenaAllocator.init(alloc);
    defer arena.deinit();

    const prompt = try Workflow.format(alloc, self.prompt, config, inputs, graph, self.inputs);
    defer alloc.free(prompt);

    const model = (if (config.ollama) |o| o.default_model else self.model) orelse "llama3.2";

    var images = std.ArrayList(ollama.types.Image).init(alloc);
    defer {
        for (images.items) |img| alloc.free(img);
        images.deinit();
    }

    if (self.images) |self_images| {
        for (self_images) |self_img| {
            const img = try self_img.toOllama(alloc, config, inputs, graph);
            errdefer alloc.free(img);

            try images.append(img);
        }
    }

    var client: ollama.Ollama = if (config.ollama) |o| o.toOllama(arena.allocator()) else .{ .allocator = arena.allocator() };
    defer client.deinit();

    var result = std.ArrayList(u8).init(alloc);
    defer result.deinit();

    const responses = try client.generate(.{
        .model = model,
        .prompt = prompt,
        .images = images.items,
    });

    while (try responses.next()) |resp| {
        try result.appendSlice(resp.response);
    }

    return try result.toOwnedSlice();
}
