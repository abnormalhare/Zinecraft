const std = @import("std");

const Tesselator = @import("../tesselator.zig").Tesselator;
const Level = @import("../level.zig").Level;
const AABB = @import("../../phys/aabb.zig").AABB;
const ParticleEngine = @import("../../particle/particle_engine.zig").ParticleEngine;
const Particle = @import("../../particle/particle.zig").Particle;

const DirtTile = @import("dirt_tile.zig").DirtTile;
const GrassTile = @import("grass_tile.zig").GrassTile;

pub const empty: ?Tile = null;
pub const rock: Tile = .{ .normal = GenericTile.init(1, 1) };
pub const grass: Tile = .{ .grass = GrassTile.init(2) };
pub const dirt: Tile = .{ .dirt = DirtTile.init(3, 2) };
pub const stone_brick: Tile = .{ .normal = GenericTile.init(4, 16) };
pub const wood: Tile = .{ .normal = GenericTile.init(5, 4) };

pub var tiles: [256]?Tile = [_]?Tile{
    empty,
    rock,
    grass,
    dirt,
    stone_brick,
    wood,
} ++ [_]?Tile{empty} ** (256 - 6);

pub const GenericTile = struct {
    tex: i32,
    id: i32,

    pub fn init(id: i32, tex: i32) GenericTile {
        const self = GenericTile{
            .tex = tex,
            .id = id,
        };

        return self;
    }

    pub fn _get_tex(self: *const GenericTile) i32 {
        return self.tex;
    }

    pub fn _get_id(self: *const GenericTile) i32 {
        return self.id;
    }

    pub fn get_texture(self: *const GenericTile) i32 {
        return self.tex;
    }

    pub fn _blocks_light(self: *const GenericTile) bool {
        _ = self;
        return true;
    }

    pub fn _is_solid(self: *const GenericTile) bool {
        _ = self;
        return true;
    }

    pub fn tick(self: *const GenericTile) void {
        _ = self;
    }
};

pub const Tile = union(enum) {
    normal: GenericTile,
    dirt: DirtTile,
    grass: GrassTile,

    pub fn get_id(self: Tile) i32 {
        switch (self) {
            inline else => |t| return t._get_id(),
        }
    }

    pub fn get_tex(self: Tile) i32 {
        switch (self) {
            inline else => |t| return t._get_tex(),
        }
    }

    pub fn render(self: Tile, t: *Tesselator, level: *Level, layer: i32, x: i32, y: i32, z: i32) void {
        const c1: f32 = 1.0;
        const c2: f32 = 0.8;
        const c3: f32 = 0.6;

        if (self.should_render_face(level, x, y - 1, z, layer)) {
            t.color(c1, c1, c1);
            self.render_face(t, x, y, z, 0);
        }

        if (self.should_render_face(level, x, y + 1, z, layer)) {
            t.color(c1, c1, c1);
            self.render_face(t, x, y, z, 1);
        }

        if (self.should_render_face(level, x, y, z - 1, layer)) {
            t.color(c2, c2, c2);
            self.render_face(t, x, y, z, 2);
        }

        if (self.should_render_face(level, x, y, z + 1, layer)) {
            t.color(c2, c2, c2);
            self.render_face(t, x, y, z, 3);
        }

        if (self.should_render_face(level, x - 1, y, z, layer)) {
            t.color(c3, c3, c3);
            self.render_face(t, x, y, z, 4);
        }

        if (self.should_render_face(level, x + 1, y, z, layer)) {
            t.color(c3, c3, c3);
            self.render_face(t, x, y, z, 5);
        }
    }

    fn should_render_face(self: Tile, level: *Level, x: i32, y: i32, z: i32, layer: i32) bool {
        _ = self;
        return !level.is_solid_tile(x, y, z) and level.is_lit(x, y, z) ^ (layer == 1);
    }

    pub fn get_texture(self: Tile, face: i32) i32 {
        return switch (self) {
            .normal => |n| n.get_texture(),
            .dirt => |d| d.get_texture(),
            .grass => |g| g.get_texture(face),
        };
    }

    pub fn render_face(self: Tile, t: *Tesselator, x: i32, y: i32, z: i32, face: i32) void {
        const tex = self.get_texture(face);

        const um0 = @as(f32, @floatFromInt(@rem(tex, 16))) / 16.0;
        const um1 = um0 + 0.999 / 16.0;
        const v0 = @as(f32, @floatFromInt(@divTrunc(tex, 16))) / 16.0;
        const v1 = v0 + 0.999 / 16.0;

        const x0: f32 = @as(f32, @floatFromInt(x)) + 0.0;
        const x1: f32 = @as(f32, @floatFromInt(x)) + 1.0;
        const y0: f32 = @as(f32, @floatFromInt(y)) + 0.0;
        const y1: f32 = @as(f32, @floatFromInt(y)) + 1.0;
        const z0: f32 = @as(f32, @floatFromInt(z)) + 0.0;
        const z1: f32 = @as(f32, @floatFromInt(z)) + 1.0;

        switch (face) {
            0 => {
                t.vertex_uv(x0, y0, z1, um0, v1);
                t.vertex_uv(x0, y0, z0, um0, v0);
                t.vertex_uv(x1, y0, z0, um1, v0);
                t.vertex_uv(x1, y0, z1, um1, v1);
            },
            1 => {
                t.vertex_uv(x1, y1, z1, um1, v1);
                t.vertex_uv(x1, y1, z0, um1, v0);
                t.vertex_uv(x0, y1, z0, um0, v0);
                t.vertex_uv(x0, y1, z1, um0, v1);
            },
            2 => {
                t.vertex_uv(x0, y1, z0, um1, v0);
                t.vertex_uv(x1, y1, z0, um0, v0);
                t.vertex_uv(x1, y0, z0, um0, v1);
                t.vertex_uv(x0, y0, z0, um1, v1);
            },
            3 => {
                t.vertex_uv(x0, y1, z1, um0, v0);
                t.vertex_uv(x0, y0, z1, um0, v1);
                t.vertex_uv(x1, y0, z1, um1, v1);
                t.vertex_uv(x1, y1, z1, um1, v0);
            },
            4 => {
                t.vertex_uv(x0, y1, z1, um1, v0);
                t.vertex_uv(x0, y1, z0, um0, v0);
                t.vertex_uv(x0, y0, z0, um0, v1);
                t.vertex_uv(x0, y0, z1, um1, v1);
            },
            5 => {
                t.vertex_uv(x1, y0, z1, um0, v1);
                t.vertex_uv(x1, y0, z0, um1, v1);
                t.vertex_uv(x1, y1, z0, um1, v0);
                t.vertex_uv(x1, y1, z1, um0, v0);
            },
            else => return, // maybe error?
        }
    }

    pub fn render_face_no_texture(self: Tile, t: *Tesselator, x: i32, y: i32, z: i32, face: i32) void {
        const x0: f32 = @as(f32, @floatFromInt(x)) + 0.0;
        const x1: f32 = @as(f32, @floatFromInt(x)) + 1.0;
        const y0: f32 = @as(f32, @floatFromInt(y)) + 0.0;
        const y1: f32 = @as(f32, @floatFromInt(y)) + 1.0;
        const z0: f32 = @as(f32, @floatFromInt(z)) + 0.0;
        const z1: f32 = @as(f32, @floatFromInt(z)) + 1.0;

        switch (face) {
            0 => {
                t.vertex(x0, y0, z1);
                t.vertex(x0, y0, z0);
                t.vertex(x1, y0, z0);
                t.vertex(x1, y0, z1);
            },
            1 => {
                t.vertex(x1, y1, z1);
                t.vertex(x1, y1, z0);
                t.vertex(x0, y1, z0);
                t.vertex(x0, y1, z1);
            },
            2 => {
                t.vertex(x0, y1, z0);
                t.vertex(x1, y1, z0);
                t.vertex(x1, y0, z0);
                t.vertex(x0, y0, z0);
            },
            3 => {
                t.vertex(x0, y1, z1);
                t.vertex(x0, y0, z1);
                t.vertex(x1, y0, z1);
                t.vertex(x1, y1, z1);
            },
            4 => {
                t.vertex(x0, y1, z1);
                t.vertex(x0, y1, z0);
                t.vertex(x0, y0, z0);
                t.vertex(x0, y0, z1);
            },
            5 => {
                t.vertex(x1, y0, z1);
                t.vertex(x1, y0, z0);
                t.vertex(x1, y1, z0);
                t.vertex(x1, y1, z1);
            },
            else => return, // maybe error?
        }

        _ = self;
    }

    pub fn get_aabb(x: i32, y: i32, z: i32) AABB {
        return AABB{ .x0 = x, .y0 = y, .z0 = z, .x1 = x + 1, .y1 = y + 1, .z1 = z + 1 };
    }

    pub fn blocks_light(self: Tile) bool {
        return switch (self) {
            inline else => |t| t._blocks_light(),
        };
    }

    pub fn is_solid(self: Tile) bool {
        return switch (self) {
            inline else => |t| t._is_solid(),
        };
    }

    pub fn tick(self: Tile, level: *Level, x: i32, y: i32, z: i32, rand: *std.Random) void {
        return switch (self) {
            .normal => |n| n.tick(),
            .dirt => |d| d.tick(),
            .grass => |g| g.tick(level, x, y, z, rand),
        };
    }

    pub fn destroy(self: *const Tile, level: *Level, rand: *std.Random, x: i32, y: i32, z: i32, particle_engine: *ParticleEngine) !void {
        const SD: usize = 4;

        for (0..SD) |xx| {
            for (0..SD) |yy| {
                for (0..SD) |zz| {
                    const fx: f32 = @floatFromInt(x);
                    const fy: f32 = @floatFromInt(y);
                    const fz: f32 = @floatFromInt(z);

                    const xp: f32 = fx + (@as(f32, @floatFromInt(xx)) + 0.5) / @as(f32, @floatFromInt(SD));
                    const yp: f32 = fy + (@as(f32, @floatFromInt(yy)) + 0.5) / @as(f32, @floatFromInt(SD));
                    const zp: f32 = fz + (@as(f32, @floatFromInt(zz)) + 0.5) / @as(f32, @floatFromInt(SD));

                    try particle_engine.add(Particle.init(level, rand, xp, yp, zp, xp - fx - 0.5, yp - fy - 0.5, zp - fz - 0.5, self.get_tex()));
                }
            }
        }
    }
};
