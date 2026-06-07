const std = @import("std");
const gl = @import("gl");

const Level = @import("level.zig").Level;
const Tesselator = @import("tesselator.zig").Tesselator;
const AABB = @import("../phys/aabb.zig").AABB;
const Textures = @import("../textures.zig");
const TileFile = @import("tile.zig");

var t: Tesselator = undefined;

pub var rebuilt_this_frame: i32 = 0;
pub var updates: i32 = 0;

pub fn init(alloc: std.mem.Allocator) !void {
    t = try Tesselator.new(alloc);
}

pub fn deinit(alloc: std.mem.Allocator) void {
    t.deinit(alloc);
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

    dirty: bool,
    lists: i32,

    pub fn new(level: *Level, x0: i32, y0: i32, z0: i32, x1: i32, y1: i32, z1: i32) Chunk {
        return Chunk{
            .level = level,
            .x0 = x0,
            .y0 = y0,
            .z0 = z0,
            .x1 = x1,
            .y1 = y1,
            .z1 = z1,
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
        };
    }

    fn rebuild(self: *Chunk, layer: i32) !void {
        if (rebuilt_this_frame == 2) return;

        self.dirty = false;
        updates += 1;
        rebuilt_this_frame += 1;

        const id = try Textures.load_texture("terrain.png", gl.GL_NEAREST);

        gl.glNewList(@intCast(self.lists + layer), gl.GL_COMPILE);
        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(id));

        t.init();

        var tiles: i32 = 0;
        for (@intCast(self.x0)..@intCast(self.x1)) |x| {
            for (@intCast(self.y0)..@intCast(self.y1)) |y| {
                for (@intCast(self.z0)..@intCast(self.z1)) |z| {
                    if (!self.level.is_tile(@intCast(x), @intCast(y), @intCast(z))) continue;

                    tiles += 1;

                    const tex: bool = (y != @divTrunc(self.level.depth * 2, 3));
                    if (!tex) {
                        TileFile.rock.render(&t, self.level, layer, @intCast(x), @intCast(y), @intCast(z));
                    } else {
                        TileFile.grass.render(&t, self.level, layer, @intCast(x), @intCast(y), @intCast(z));
                    }
                }
            }
        }

        t.flush();

        gl.glDisable(gl.GL_TEXTURE_2D);
        gl.glEndList();
    }

    pub fn render(self: *Chunk, layer: i32) !void {
        if (self.dirty) {
            try self.rebuild(0);
            try self.rebuild(1);
        }

        gl.glCallList(@intCast(self.lists + layer));
    }

    pub fn set_dirty(self: *Chunk) void {
        self.dirty = true;
    }
};
