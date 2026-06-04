const std = @import("std");
const minecraft = @import("minecraft");

pub fn main(init: std.process.Init) !void {
    const alloc = init.arena.allocator();
    const io = init.io;

    try minecraft.run(alloc, io);
}
