const std = @import("std");
const gl = @import("gl");

const Level = @import("level.zig").Level;
const Tesselator = @import("tesselator.zig").Tesselator;
const TesselatorFile = @import("tesselator.zig");
const AABB = @import("../phys/aabb.zig").AABB;
const Textures = @import("../textures.zig");
const TileFile = @import("tile/tile.zig");
const Player = @import("../player.zig").Player;

var t: *Tesselator = undefined;

pub var updates: i32 = 0;
pub var total_time: i96 = 0;
pub var total_updates: i32 = 0;

pub fn init() void {
    t = &TesselatorFile.instance;
}

pub const Chunk = struct {
    aabb: AABB,
    level: *Level,

    x0: i32,
    y0: i32,
    z0: i32,
    x1: i32,
    y1: i32,
    z1: i32,

    x: f32,
    y: f32,
    z: f32,

    dirty: bool,
    lists: i32,
    dirtied_time: i64,

    pub fn new(level: *Level, x0: i32, y0: i32, z0: i32, x1: i32, y1: i32, z1: i32) Chunk {
        return Chunk{
            .level = level,
            .x0 = x0,
            .y0 = y0,
            .z0 = z0,
            .x1 = x1,
            .y1 = y1,
            .z1 = z1,

            .x = @as(f32, @floatFromInt(x0 + x1)) / 2.0,
            .y = @as(f32, @floatFromInt(y0 + y1)) / 2.0,
            .z = @as(f32, @floatFromInt(z0 + z1)) / 2.0,

            .aabb = AABB{
                .x0 = @floatFromInt(x0),
                .y0 = @floatFromInt(y0),
                .z0 = @floatFromInt(z0),
                .x1 = @floatFromInt(x1),
                .y1 = @floatFromInt(y1),
                .z1 = @floatFromInt(z1),
            },

            .dirty = true,
            .lists = @bitCast(gl.glGenLists(2)),
            .dirtied_time = 0,
        };
    }

    fn rebuild_layer(self: *Chunk, io: std.Io, layer: i32) !void {
        self.dirty = false;
        updates += 1;

        const before: i96 = std.Io.Clock.now(.real, io).nanoseconds;

        gl.glNewList(@intCast(self.lists + layer), gl.GL_COMPILE);

        t.init();

        var tiles: i32 = 0;
        for (@intCast(self.x0)..@intCast(self.x1)) |x| {
            for (@intCast(self.y0)..@intCast(self.y1)) |y| {
                for (@intCast(self.z0)..@intCast(self.z1)) |z| {
                    const tile_id = self.level.get_tile(@intCast(x), @intCast(y), @intCast(z));
                    if (tile_id > 0) {
                        TileFile.tiles[@intCast(tile_id)].?.render(t, self.level, layer, @intCast(x), @intCast(y), @intCast(z));
                        tiles += 1;
                    }
                }
            }
        }

        t.flush();
        gl.glEndList();

        const after: i96 = std.Io.Clock.now(.real, io).nanoseconds;
        if (tiles > 0) {
            total_time += after - before;
            total_updates += 1;
        }
    }

    pub fn rebuild(self: *Chunk, io: std.Io) !void {
        try self.rebuild_layer(io, 0);
        try self.rebuild_layer(io, 1);
    }

    pub fn render(self: *Chunk, layer: i32) !void {
        gl.glCallList(@intCast(self.lists + layer));
    }

    pub fn set_dirty(self: *Chunk, io: std.Io) void {
        if (!self.dirty) {
            self.dirtied_time = std.Io.Clock.now(.real, io).toMilliseconds();
        }

        self.dirty = true;
    }

    pub fn distance_to_sqr(self: *const Chunk, player: *Player) f32 {
        const xd: f32 = player.entity.x - self.x;
        const yd: f32 = player.entity.y - self.y;
        const zd: f32 = player.entity.z - self.z;

        return xd * xd + yd * yd + zd * zd;
    }
};
