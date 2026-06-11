const std = @import("std");
const options = @import("options");
const minecraft = @import("minecraft");

pub fn main(init: std.process.Init) !void {
    const create_alloc = init.arena.allocator();
    const io = init.io;

    if (options.connection == .client) {
        try minecraft.run(create_alloc, io);
    } else {
        const alloc = std.heap.page_allocator;

        const server: *minecraft.MinecraftServer = try .new(io, create_alloc, alloc, "127.0.0.1", 20801);
        defer {
            server.deinit();
            create_alloc.destroy(server);
        }

        server.run(io);
    }
}
