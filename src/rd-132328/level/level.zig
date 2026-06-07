const std = @import("std");
const flate = std.compress.flate;

const AABB = @import("../phys/aabb.zig").AABB;
const LevelListener = @import("level_listener.zig").LevelListener;

pub const Level = struct {
    width: i32,
    height: i32,
    depth: i32,
    blocks: []u8,
    light_depths: []i32,
    level_listeners: std.ArrayList(LevelListener(*const anyopaque)),

    level_alloc: std.mem.Allocator,

    pub fn new(alloc: std.mem.Allocator, level_alloc: std.mem.Allocator, w: i32, h: i32, d: i32) !Level {
        var blocks = try alloc.alloc(u8, @intCast(w * h * d));
        const light_depths = try alloc.alloc(i32, @intCast(w * h));

        const width: usize = @intCast(w);
        const height: usize = @intCast(h);
        const depth: usize = @intCast(d);

        for (0..width) |x| {
            for (0..depth) |y| {
                for (0..height) |z| {
                    const i = (y * height + z) * width + x;
                    if (y <= (depth * 2 / 3)) {
                        blocks[i] = 1;
                    } else {
                        blocks[i] = 0;
                    }
                }
            }
        }

        var self = Level{
            .width = w,
            .height = h,
            .depth = d,

            .blocks = blocks,
            .light_depths = light_depths,

            .level_listeners = .empty,
            .level_alloc = level_alloc,
        };

        self.calc_light_depths(0, 0, w, h);
        try self.load();

        return self;
    }

    pub fn deinit(self: *Level, alloc: std.mem.Allocator) void {
        self.level_listeners.deinit(self.level_alloc);

        alloc.free(self.light_depths);
        alloc.free(self.blocks);
    }

    pub fn load(self: *Level) !void {
        var io_thread: std.Io.Threaded = .init_single_threaded;
        const io = io_thread.io();

        const file = std.Io.Dir.cwd().openFile(io, "level.dat", .{ .mode = .read_only }) catch |err| blk: {
            std.debug.print("File must be created/overwritten: {}\n", .{err});
            break :blk try std.Io.Dir.cwd().createFile(io, "level.dat", .{ .read = true });
        };
        defer file.close(io);

        const stat = try file.stat(io);
        if (stat.size == 0) return;

        var read_buffer: [flate.max_window_len]u8 = undefined;
        var reader: std.Io.File.Reader = .init(file, io, &read_buffer);

        var flate_buffer: [flate.max_window_len]u8 = undefined;
        var decompress: flate.Decompress = .init(
            &reader.interface,
            .gzip,
            &flate_buffer,
        );

        decompress.reader.readSliceAll(self.blocks) catch |err| {
            std.debug.print("ERROR: {} | {any}\n", .{ err, decompress.err });
            return err;
        };

        self.calc_light_depths(0, 0, self.width, self.height);
        for (self.level_listeners.items) |listener| {
            listener.all_changed(listener.base);
        }
    }

    pub fn save(self: *Level) !void {
        var io_thread: std.Io.Threaded = .init_single_threaded;
        const io = io_thread.io();

        const file = try std.Io.Dir.cwd().createFile(io, "level.dat", .{});
        defer file.close(io);

        var write_buffer: [flate.max_window_len]u8 = undefined;
        var writer: std.Io.File.Writer = .init(file, io, &write_buffer);

        var flate_buffer: [flate.max_window_len]u8 = undefined;
        var compress: flate.Compress = try .init(
            &writer.interface,
            &flate_buffer,
            .gzip,
            .level_6,
        );

        try compress.writer.writeAll(self.blocks);
        try compress.finish();

        try compress.writer.flush();
        try writer.interface.flush();
    }

    pub fn calc_light_depths(self: *Level, x0: i32, y0: i32, x1: i32, y1: i32) void {
        const x0s: usize = @intCast(x0);
        const y0s: usize = @intCast(y0);
        const x1s: usize = @intCast(x1);
        const y1s: usize = @intCast(y1);

        for (x0s..(x0s + x1s)) |x| {
            for (y0s..(y0s + y1s)) |z| {
                const width = @as(usize, @intCast(self.width));
                const old_depth = self.light_depths[z * width + x];

                var y: usize = @intCast(self.depth - 1);
                while (y > 0) : (y -= 1) {
                    if (self.is_light_blocker(@intCast(x), @intCast(y), @intCast(z))) {
                        break;
                    }
                }

                self.light_depths[z * width + x] = @intCast(y);
                if (old_depth != y) {
                    const y10: i32 = if (old_depth < y) old_depth else @intCast(y);
                    const y11: i32 = if (old_depth > y) old_depth else @intCast(y);

                    for (self.level_listeners.items) |listener| {
                        listener.light_column_changed(listener.base, @intCast(x), @intCast(z), y10, y11);
                    }
                }
            }
        }
    }

    pub fn add_listener(self: *Level, level_listener: LevelListener(*const anyopaque)) !void {
        try self.level_listeners.append(self.level_alloc, level_listener);
    }

    pub fn remove_listener(self: *Level, level_listener: LevelListener(*const anyopaque)) void {
        for (self.level_listeners.items, 0..) |item, idx| {
            if (item.base == level_listener.base) {
                self.level_listeners.swapRemove(idx);
            }
        }
    }

    pub fn is_tile(self: *Level, x: i32, y: i32, z: i32) bool {
        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const index: usize = @intCast((y * self.height + z) * self.width + x);
            return self.blocks[index] == 1;
        } else {
            return false;
        }
    }

    pub fn is_solid_tile(self: *Level, x: i32, y: i32, z: i32) bool {
        return self.is_tile(x, y, z);
    }

    pub fn is_light_blocker(self: *Level, x: i32, y: i32, z: i32) bool {
        return self.is_solid_tile(x, y, z);
    }

    pub fn get_cubes(self: *Level, alloc: std.mem.Allocator, aABB: *AABB) !std.ArrayList(AABB) {
        var aABBs: std.ArrayList(AABB) = .empty;

        var x0: i32 = @intFromFloat(aABB.x0);
        var x1: i32 = @intFromFloat(aABB.x1 + 1.0);
        var y0: i32 = @intFromFloat(aABB.y0);
        var y1: i32 = @intFromFloat(aABB.y1 + 1.0);
        var z0: i32 = @intFromFloat(aABB.z0);
        var z1: i32 = @intFromFloat(aABB.z1 + 1.0);

        if (x0 < 0) {
            x0 = 0;
        }
        if (y0 < 0) {
            y0 = 0;
        }
        if (z0 < 0) {
            z0 = 0;
        }

        if (x1 > self.width) {
            x1 = @intCast(self.width);
        }
        if (y1 > self.depth) {
            y1 = @intCast(self.depth);
        }
        if (z1 > self.height) {
            z1 = @intCast(self.height);
        }

        if (x0 >= x1 or y0 >= y1 or z0 >= z1) return aABBs;

        const x0s: usize = @intCast(x0);
        const y0s: usize = @intCast(y0);
        const z0s: usize = @intCast(z0);
        const x1s: usize = @intCast(x1);
        const y1s: usize = @intCast(y1);
        const z1s: usize = @intCast(z1);

        for (x0s..x1s) |x| {
            for (y0s..y1s) |y| {
                for (z0s..z1s) |z| {
                    const ix: i32 = @intCast(x);
                    const iy: i32 = @intCast(y);
                    const iz: i32 = @intCast(z);
                    if (self.is_solid_tile(ix, iy, iz)) {
                        try aABBs.append(alloc, AABB{
                            .x0 = @floatFromInt(ix),
                            .y0 = @floatFromInt(iy),
                            .z0 = @floatFromInt(iz),
                            .x1 = @floatFromInt(ix + 1),
                            .y1 = @floatFromInt(iy + 1),
                            .z1 = @floatFromInt(iz + 1),
                        });
                    }
                }
            }
        }

        return aABBs;
    }

    pub fn get_brightness(self: *Level, x: i32, y: i32, z: i32) f32 {
        const dark: f32 = 0.8;
        const light: f32 = 1.0;

        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const idx: usize = @intCast(z * self.width + x);
            if (y < self.light_depths[idx]) {
                return dark;
            }
            return light;
        }
        return light;
    }

    pub fn set_tile(self: *Level, x: i32, y: i32, z: i32, ttype: i32) void {
        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const idx: usize = @intCast((y * self.height + z) * self.width + x);
            self.blocks[idx] = @as(u8, @intCast(ttype));
            self.calc_light_depths(x, z, 1, 1);

            for (self.level_listeners.items) |listener| {
                listener.tile_changed(listener.base, x, y, z);
            }
        }
    }
};
