const std = @import("std");
const gl = @import("gl");

const AABB = @import("../phys/aabb.zig").AABB;
const ChunkFile = @import("chunk.zig");
const Chunk = @import("chunk.zig").Chunk;
const HitResult = @import("../hit_result.zig").HitResult;
const Frustum = @import("frustum.zig").Frustum;
const Level = @import("level.zig").Level;
const LevelListener = @import("level_listener.zig").LevelListener;
const Player = @import("../player.zig").Player;
const Tesselator = @import("tesselator.zig").Tesselator;
const Textures = @import("../textures.zig");
const TileFile = @import("tile.zig");

const CHUNK_SIZE: i32 = 16;

pub const LevelRenderer = struct {
    listener: LevelListener(*const anyopaque),

    level: *Level,
    chunks: []Chunk,

    x_chunks: i32,
    y_chunks: i32,
    z_chunks: i32,

    t: Tesselator,

    pub fn new(alloc: std.mem.Allocator, level: *Level) !*LevelRenderer {
        var self = try alloc.create(LevelRenderer);
        self.* = LevelRenderer{
            .listener = undefined,

            .level = level,
            .chunks = undefined,

            .x_chunks = @divFloor(level.width, 16),
            .y_chunks = @divFloor(level.depth, 16),
            .z_chunks = @divFloor(level.height, 16),

            .t = try Tesselator.new(alloc),
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
                    const x0: i32 = @as(i32, @intCast(x)) * 16;
                    const y0: i32 = @as(i32, @intCast(y)) * 16;
                    const z0: i32 = @as(i32, @intCast(z)) * 16;
                    var x1: i32 = @as(i32, @intCast(x + 1)) * 16;
                    var y1: i32 = @as(i32, @intCast(y + 1)) * 16;
                    var z1: i32 = @as(i32, @intCast(z + 1)) * 16;
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

    pub fn render(self: *LevelRenderer, player: *Player, layer: i32) void {
        ChunkFile.rebuilt_this_frame = 0;
        const frustum: *Frustum = Frustum.get_frustum();

        for (self.chunks) |*chunk| {
            if (frustum.cube_in_frustum_aabb(chunk.aabb)) {
                chunk.render(layer);
            }
        }

        _ = player;
    }

    pub fn pick(self: *LevelRenderer, player: *Player) void {
        const r: f32 = 3.0;
        const box: AABB = player.bb.grow(r, r, r);

        const x0 = @as(usize, @intFromFloat(box.x0));
        const x1 = @as(usize, @intFromFloat(box.x1 + 1));
        const y0 = @as(usize, @intFromFloat(box.y0));
        const y1 = @as(usize, @intFromFloat(box.y1 + 1));
        const z0 = @as(usize, @intFromFloat(box.z0));
        const z1 = @as(usize, @intFromFloat(box.z1 + 1));

        gl.glInitNames();
        for (x0..x1) |x| {
            gl.glPushName(@intCast(x));
            for (y0..y1) |y| {
                gl.glPushName(@intCast(y));
                for (z0..z1) |z| {
                    gl.glPushName(@intCast(z));
                    if (self.level.is_solid_tile(@intCast(x), @intCast(y), @intCast(z))) {
                        gl.glPushName(0);
                        for (0..6) |i| {
                            gl.glPushName(@intCast(i));

                            self.t.init();
                            TileFile.rock.render_face(
                                &self.t,
                                @intCast(x),
                                @intCast(y),
                                @intCast(z),
                                @intCast(i),
                            );
                            self.t.flush();

                            gl.glPopName();
                        }

                        gl.glPopName();
                    }

                    gl.glPopName();
                }

                gl.glPopName();
            }

            gl.glPopName();
        }
    }

    pub fn render_hit(self: *LevelRenderer, io: std.Io, h: HitResult) void {
        const curr_time = std.Io.Clock.now(.real, io);

        gl.glEnable(gl.GL_BLEND);
        gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE);
        gl.glColor4f(1.0, 1.0, 1.0, @floatCast(@sin(@as(f64, @floatFromInt(curr_time.toMilliseconds())) / 100.0) * 0.2 + 0.4));

        self.t.init();
        TileFile.rock.render_face(&self.t, h.x, h.y, h.z, h.f);
        self.t.flush();

        gl.glDisable(gl.GL_BLEND);
    }

    pub fn set_dirty(self: *LevelRenderer, x0: i32, y0: i32, z0: i32, x1: i32, y1: i32, z1: i32) void {
        const x0n: i32 = if (x0 < 0) 0 else @intCast(@divFloor(x0, 16));
        const x1n: i32 = if (x1 >= self.x_chunks) @intCast(self.x_chunks - 1) else @intCast(@divFloor(x1, 16));
        const y0n: i32 = if (y0 < 0) 0 else @intCast(@divFloor(y0, 16));
        const y1n: i32 = if (y1 >= self.y_chunks) @intCast(self.y_chunks - 1) else @intCast(@divFloor(y1, 16));
        const z0n: i32 = if (z0 < 0) 0 else @intCast(@divFloor(z0, 16));
        const z1n: i32 = if (z1 >= self.z_chunks) @intCast(self.z_chunks - 1) else @intCast(@divFloor(z1, 16));

        // std.debug.print("dirty: {} <={} | {} <= {} | {} <= {}\n", .{ x0n, x1n, y0n, y1n, z0n, z1n });

        var x: i32 = x0n;
        var y: i32 = y0n;
        var z: i32 = z0n;
        while (x <= x1n) : (x += 1) {
            while (y <= y1n) : (y += 1) {
                while (z <= z1n) : (z += 1) {
                    const idx: usize = @intCast((y * self.x_chunks + x) * self.z_chunks + z);
                    self.chunks[idx].set_dirty();
                }
            }
        }
    }

    pub fn tile_changed(self: *LevelRenderer, x: i32, y: i32, z: i32) void {
        std.debug.print("chunks: {} {} {}\n", .{ self.x_chunks, self.y_chunks, self.z_chunks });
        self.set_dirty(x - 1, y - 1, z - 1, x + 1, y + 1, z + 1);
    }

    pub fn light_column_changed(self: *LevelRenderer, x: i32, z: i32, y0: i32, y1: i32) void {
        self.set_dirty(x - 1, y0 - 1, z - 1, x + 1, y1 + 1, z + 1);
    }

    pub fn all_changed(self: *LevelRenderer) void {
        self.set_dirty(0, 0, 0, self.level.width, self.level.depth, self.level.height);
    }
};
