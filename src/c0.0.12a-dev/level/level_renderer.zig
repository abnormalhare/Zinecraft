const std = @import("std");
const gl = @import("gl");

const AABB = @import("../phys/aabb.zig").AABB;
const ChunkFile = @import("chunk.zig");
const Chunk = @import("chunk.zig").Chunk;
const DirtyChunkSorter = @import("dirty_chunk_sorter.zig").DirtyChunkSorter;
const HitResult = @import("../hit_result.zig").HitResult;
const Frustum = @import("../render/frustum.zig").Frustum;
const Level = @import("level.zig").Level;
const LevelListener = @import("level_listener.zig").LevelListener;
const Player = @import("../player.zig").Player;
const Tesselator = @import("../render/tesselator.zig").Tesselator;
const TesselatorFile = @import("../render/tesselator.zig");
const Textures = @import("../render/textures.zig").Textures;
const TileFile = @import("tile/tile.zig");

const MAX_REBUILDS_PER_FRAME: usize = 8;
const CHUNK_SIZE: i32 = 16;

pub const LevelRenderer = struct {
    io: std.Io,

    listener: LevelListener(*const anyopaque),

    level: *Level,
    chunks: []Chunk,

    x_chunks: i32,
    y_chunks: i32,
    z_chunks: i32,

    textures: *Textures,

    pub fn new(alloc: std.mem.Allocator, io: std.Io, level: *Level, textures: *Textures) !*LevelRenderer {
        var self = try alloc.create(LevelRenderer);
        self.* = LevelRenderer{
            .io = io,

            .listener = undefined,

            .level = level,
            .chunks = undefined,

            .x_chunks = @divTrunc(level.width, CHUNK_SIZE),
            .y_chunks = @divTrunc(level.depth, CHUNK_SIZE),
            .z_chunks = @divTrunc(level.height, CHUNK_SIZE),

            .textures = textures,
        };

        self.listener = LevelListener(*const anyopaque){
            .base = @ptrCast(self),

            .tile_changed = @ptrCast(&LevelRenderer.tile_changed),
            .light_column_changed = @ptrCast(&LevelRenderer.light_column_changed),
            .all_changed = @ptrCast(&LevelRenderer.all_changed),
        };

        try self.level.add_listener(self.listener);

        self.chunks = try alloc.alloc(Chunk, @intCast(self.x_chunks * self.y_chunks * self.z_chunks));
        for (0..@intCast(self.x_chunks)) |x| {
            for (0..@intCast(self.y_chunks)) |y| {
                for (0..@intCast(self.z_chunks)) |z| {
                    const x0: i32 = @as(i32, @intCast(x)) * CHUNK_SIZE;
                    const y0: i32 = @as(i32, @intCast(y)) * CHUNK_SIZE;
                    const z0: i32 = @as(i32, @intCast(z)) * CHUNK_SIZE;
                    var x1: i32 = @as(i32, @intCast(x + 1)) * CHUNK_SIZE;
                    var y1: i32 = @as(i32, @intCast(y + 1)) * CHUNK_SIZE;
                    var z1: i32 = @as(i32, @intCast(z + 1)) * CHUNK_SIZE;
                    if (x1 > level.width) x1 = level.width;
                    if (y1 > level.depth) y1 = level.depth;
                    if (z1 > level.height) z1 = level.height;

                    const x_chunks: usize = @intCast(self.x_chunks);
                    const z_chunks: usize = @intCast(self.z_chunks);
                    self.chunks[(y * x_chunks + x) * z_chunks + z] = .new(level, x0, y0, z0, x1, y1, z1);
                }
            }
        }

        return self;
    }

    pub fn deinit(self: *LevelRenderer, alloc: std.mem.Allocator) void {
        alloc.free(self.chunks);
    }

    // returns alloc'd arraylist, not contained
    fn get_all_dirty_chunks(self: *LevelRenderer, alloc: std.mem.Allocator) !std.ArrayList(*Chunk) {
        var dirty: std.ArrayList(*Chunk) = .empty;

        for (self.chunks) |*chunk| {
            if (chunk.dirty) {
                try dirty.append(alloc, chunk);
            }
        }

        return dirty;
    }

    pub fn render(self: *LevelRenderer, player: *Player, layer: i32) !void {
        gl.glEnable(gl.GL_TEXTURE_2D);

        const id = try self.textures.load_texture("terrain.png", gl.GL_NEAREST);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(id));

        const frustum = Frustum.get_frustum();

        for (self.chunks) |*chunk| {
            if (frustum.is_visible(chunk.aabb)) {
                try chunk.render(layer);
            }
        }

        gl.glDisable(gl.GL_TEXTURE_2D);

        _ = player;
    }

    // alloc is contained
    pub fn update_dirty_chunks(self: *LevelRenderer, alloc: std.mem.Allocator, player: *Player) !void {
        var dirty = try self.get_all_dirty_chunks(alloc);
        defer dirty.deinit(alloc);

        if (dirty.items.len == 0) return;

        std.mem.sort(*Chunk, dirty.items, DirtyChunkSorter.new(self.io, player, Frustum.get_frustum()), DirtyChunkSorter.compare);

        for (0..MAX_REBUILDS_PER_FRAME) |i| {
            if (i == dirty.items.len) return;

            try dirty.items[i].rebuild(self.io);
        }
    }

    pub fn pick(self: *LevelRenderer, player: *Player, frustum: *Frustum) void {
        const t = &TesselatorFile.instance;

        const r: f32 = 3.0;
        const box: AABB = player.entity.bb.grow(r, r, r);

        const x0: i32 = @intFromFloat(box.x0);
        const x1: i32 = @intFromFloat(box.x1 + 1);
        const y0: i32 = @intFromFloat(box.y0);
        const y1: i32 = @intFromFloat(box.y1 + 1);
        const z0: i32 = @intFromFloat(box.z0);
        const z1: i32 = @intFromFloat(box.z1 + 1);

        gl.glInitNames();
        gl.glPushName(0);
        gl.glPushName(0);

        var x: i32 = x0;
        while (x < x1) : (x += 1) {
            gl.glLoadName(@intCast(@as(u32, @bitCast(x))));
            gl.glPushName(0);

            var y: i32 = y0;
            while (y < y1) : (y += 1) {
                gl.glLoadName(@intCast(@as(u32, @bitCast(y))));
                gl.glPushName(0);

                var z: i32 = z0;
                while (z < z1) : (z += 1) {
                    const tile = TileFile.tiles[@intCast(self.level.get_tile(x, y, z))];
                    if (tile != null and frustum.is_visible(tile.?.get_tile_aabb(x, y, z))) {
                        gl.glLoadName(@intCast(@as(u32, @bitCast(z))));
                        gl.glPushName(0);

                        for (0..6) |i| {
                            gl.glLoadName(@intCast(i));

                            t.init();
                            tile.?.render_face_no_texture(
                                t,
                                @intCast(x),
                                @intCast(y),
                                @intCast(z),
                                @intCast(i),
                            );
                            t.flush();
                        }

                        gl.glPopName();
                    }
                }

                gl.glPopName();
            }

            gl.glPopName();
        }

        gl.glPopName();
        gl.glPopName();
    }

    pub fn render_hit(self: *LevelRenderer, h: HitResult, mode: i32, tile_type: i32) !void {
        const curr_time = std.Io.Clock.now(.real, self.io).toMilliseconds();
        const t = &TesselatorFile.instance;

        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE);
        gl.glColor4f(1.0, 1.0, 1.0, @floatCast(@sin(@as(f64, @floatFromInt(curr_time)) / 100.0) * 0.2 + 0.4));

        switch (mode) {
            0 => {
                t.init();
                TileFile.rock.render_face_no_texture(t, h.x, h.y, h.z, h.f);
                t.flush();
            },
            else => {
                gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);

                const curr_time1 = std.Io.Clock.now(.real, self.io).toMilliseconds();
                const color: f32 = @as(f32, @floatCast(@sin(@as(f64, @floatFromInt(curr_time1)) / 100.0))) * 0.2 + 0.8;
                const curr_time2 = std.Io.Clock.now(.real, self.io).toMilliseconds();
                const alpha: f32 = @as(f32, @floatCast(@sin(@as(f64, @floatFromInt(curr_time2)) / 200.0))) * 0.2 + 0.5;
                gl.glColor4f(color, color, color, alpha);

                gl.glEnable(gl.GL_TEXTURE_2D);
                const id = try self.textures.load_texture("terrain.png", gl.GL_NEAREST);
                gl.glBindTexture(gl.GL_TEXTURE_2D, @bitCast(id));

                var x = h.x;
                var y = h.y;
                var z = h.z;
                switch (h.f) {
                    0 => y -= 1,
                    1 => y += 1,
                    2 => z -= 1,
                    3 => z += 1,
                    4 => x -= 1,
                    5 => x += 1,
                    else => {},
                }

                t.init();
                t.set_no_color();

                TileFile.tiles[@intCast(tile_type)].?.render(t, self.level, 0, x, y, z);
                TileFile.tiles[@intCast(tile_type)].?.render(t, self.level, 1, x, y, z);

                t.flush();
                gl.glDisable(gl.GL_TEXTURE_2D);
            },
        }

        gl.glDisable(gl.GL_BLEND);
    }

    pub fn set_dirty(self: *LevelRenderer, x0: i32, y0: i32, z0: i32, x1: i32, y1: i32, z1: i32) void {
        const x0n: i32 = if (x0 < 0) 0 else @intCast(@divTrunc(x0, CHUNK_SIZE));
        const x1n: i32 = if (x1 >= self.x_chunks) @intCast(self.x_chunks - 1) else @intCast(@divTrunc(x1, CHUNK_SIZE));
        const y0n: i32 = if (y0 < 0) 0 else @intCast(@divTrunc(y0, CHUNK_SIZE));
        const y1n: i32 = if (y1 >= self.y_chunks) @intCast(self.y_chunks - 1) else @intCast(@divTrunc(y1, CHUNK_SIZE));
        const z0n: i32 = if (z0 < 0) 0 else @intCast(@divTrunc(z0, CHUNK_SIZE));
        const z1n: i32 = if (z1 >= self.z_chunks) @intCast(self.z_chunks - 1) else @intCast(@divTrunc(z1, CHUNK_SIZE));

        var x: i32 = x0n;
        while (x <= x1n) : (x += 1) {
            var y: i32 = y0n;
            while (y <= y1n) : (y += 1) {
                var z: i32 = z0n;
                while (z <= z1n) : (z += 1) {
                    const idx: usize = @intCast((y * self.x_chunks + x) * self.z_chunks + z);
                    self.chunks[idx].set_dirty(self.io);
                }
            }
        }
    }

    pub fn tile_changed(self: *LevelRenderer, x: i32, y: i32, z: i32) void {
        self.set_dirty(x - 1, y - 1, z - 1, x + 1, y + 1, z + 1);
    }

    pub fn light_column_changed(self: *LevelRenderer, x: i32, z: i32, y0: i32, y1: i32) void {
        self.set_dirty(x - 1, y0 - 1, z - 1, x + 1, y1 + 1, z + 1);
    }

    pub fn all_changed(self: *LevelRenderer) void {
        self.set_dirty(0, 0, 0, self.level.width, self.level.depth, self.level.height);
    }
};
