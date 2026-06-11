const std = @import("std");
const flate = std.compress.flate;

const AABB = @import("../phys/aabb.zig").AABB;
const LevelListener = @import("level_listener.zig").LevelListener;
const PerlinNoiseFilter = @import("perlin_noise_filter.zig").PerlinNoiseFilter;
const TileFile = @import("tile/tile.zig");

const TILE_UPDATE_INTERNAL: i32 = 400;

pub const Level = struct {
    width: i32,
    height: i32,
    depth: i32,
    blocks: []u8,
    light_depths: []i32,

    rand: *std.Random,

    level_listeners: std.ArrayList(LevelListener(*const anyopaque)),
    level_alloc: std.mem.Allocator,

    unprocessed: i32,

    pub fn new(alloc: std.mem.Allocator, rand: *std.Random, level_alloc: std.mem.Allocator, w: i32, h: i32, d: i32) !Level {
        const blocks = try alloc.alloc(u8, @intCast(w * h * d));
        const light_depths = try alloc.alloc(i32, @intCast(w * h));

        var self = Level{
            .width = w,
            .height = h,
            .depth = d,

            .blocks = blocks,
            .light_depths = light_depths,

            .rand = rand,

            .level_listeners = .empty,
            .level_alloc = level_alloc,

            .unprocessed = 0,
        };

        const map_loaded = try self.load();
        if (!map_loaded) {
            try self.generate_map(alloc);
        }

        self.calc_light_depths(0, 0, w, h);

        return self;
    }

    pub fn deinit(self: *Level, alloc: std.mem.Allocator) void {
        self.level_listeners.deinit(self.level_alloc);

        alloc.free(self.light_depths);
        alloc.free(self.blocks);
    }

    // alloc is contained
    fn generate_map(self: *Level, alloc: std.mem.Allocator) !void {
        const w: usize = @intCast(self.width);
        const h: usize = @intCast(self.height);
        const d: usize = @intCast(self.depth);

        var heightmap1filter = PerlinNoiseFilter.new(self.rand, 0);
        const heightmap1 = try heightmap1filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(heightmap1);

        var heightmap2filter = PerlinNoiseFilter.new(self.rand, 0);
        const heightmap2 = try heightmap2filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(heightmap2);

        var cf_filter = PerlinNoiseFilter.new(self.rand, 1);
        const cf = try cf_filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(cf);

        var rock_map_filter = PerlinNoiseFilter.new(self.rand, 1);
        const rock_map = try rock_map_filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(rock_map);

        for (0..w) |x| {
            for (0..d) |y| {
                for (0..h) |z| {
                    const dh1 = heightmap1[z * w + x];
                    const cfh = cf[z * w + x];
                    const dh2 = if (cfh < 128) dh1 else heightmap2[z * w + x];

                    const dh = @divTrunc(@max(dh1, dh2), 8) + @as(i32, @intCast(@divTrunc(d, 3)));

                    var rh = @divTrunc(rock_map[z * w + x], 8) + @as(i32, @intCast(@divTrunc(d, 3)));
                    if (rh > dh - 2) {
                        rh = dh - 2;
                    }

                    const i = (y * h + z) * w + x;

                    var id: i32 = 0;
                    if (y == dh) {
                        id = TileFile.grass.get_id();
                    }
                    if (y < dh) {
                        id = TileFile.dirt.get_id();
                    }
                    if (y <= rh) {
                        id = TileFile.rock.get_id();
                    }

                    self.blocks[i] = @truncate(@as(u32, @intCast(id)));
                }
            }
        }
    }

    pub fn load(self: *Level) !bool {
        var io_thread: std.Io.Threaded = .init_single_threaded;
        const io = io_thread.io();

        const file = std.Io.Dir.cwd().openFile(io, "level.dat", .{ .mode = .read_only }) catch |err| {
            std.debug.print("File must be created/overwritten: {}\n", .{err});
            const file = try std.Io.Dir.cwd().createFile(io, "level.dat", .{ .read = true });
            file.close(io);
            return false;
        };
        defer file.close(io);

        const stat = try file.stat(io);
        if (stat.size == 0) return false;

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

        return true;
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
                break;
            }
        }
    }

    pub fn is_light_blocker(self: *Level, x: i32, y: i32, z: i32) bool {
        const tile = TileFile.tiles[@intCast(self.get_tile(x, y, z))];
        if (tile == null) return false;

        return tile.?.blocks_light();
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

                    const tile = TileFile.tiles[@intCast(self.get_tile(ix, iy, iz))];
                    if (tile == null) continue;

                    try aABBs.append(alloc, tile.?.get_aabb(ix, iy, iz));
                }
            }
        }

        return aABBs;
    }

    pub fn set_tile(self: *Level, x: i32, y: i32, z: i32, ttype: i32) bool {
        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const idx: usize = @intCast((y * self.height + z) * self.width + x);
            if (ttype == self.blocks[idx]) {
                return false;
            }

            self.blocks[idx] = @as(u8, @intCast(ttype));
            self.calc_light_depths(x, z, 1, 1);

            for (self.level_listeners.items) |listener| {
                listener.tile_changed(listener.base, x, y, z);
            }

            return true;
        }

        return false;
    }

    pub fn is_lit(self: *Level, x: i32, y: i32, z: i32) bool {
        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const idx: usize = @intCast(z * self.width + x);
            return y >= self.light_depths[idx];
        } else {
            return true;
        }
    }

    pub fn get_tile(self: *Level, x: i32, y: i32, z: i32) i32 {
        if (x >= 0 and y >= 0 and z >= 0 and x < self.width and y < self.depth and z < self.height) {
            const block = (y * self.height + z) * self.width + x;
            return self.blocks[@intCast(block)];
        } else {
            return 0;
        }
    }

    pub fn is_solid_tile(self: *Level, x: i32, y: i32, z: i32) bool {
        const tile_idx = self.get_tile(x, y, z);
        const tile = TileFile.tiles[@intCast(tile_idx)];
        if (tile == null) return false;

        return tile.?.is_solid();
    }

    pub fn tick(self: *Level) void {
        self.unprocessed += self.width * self.height * self.depth;

        const ticks = @divTrunc(self.unprocessed, TILE_UPDATE_INTERNAL);
        self.unprocessed -= ticks * TILE_UPDATE_INTERNAL;

        for (0..@intCast(ticks)) |_| {
            const x = self.rand.intRangeAtMost(i32, 0, self.width - 1);
            const y = self.rand.intRangeAtMost(i32, 0, self.depth - 1);
            const z = self.rand.intRangeAtMost(i32, 0, self.height - 1);

            const tile_idx = self.get_tile(x, y, z);
            const tile = TileFile.tiles[@intCast(tile_idx)];
            if (tile != null) {
                tile.?.tick(self, x, y, z, self.rand);
            }
        }
    }
};
