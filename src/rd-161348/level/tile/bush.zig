const std = @import("std");

const TileFile = @import("tile.zig");
const Level = @import("../level.zig").Level;
const Tesselator = @import("../tesselator.zig").Tesselator;
const AABB = @import("../../phys/aabb.zig").AABB;

pub const Bush = struct {
    tex: i32,
    id: i32,

    pub fn init(id: i32) Bush {
        return Bush{
            .tex = 15,
            .id = id,
        };
    }

    pub fn _get_tex(self: *const Bush) i32 {
        return self.tex;
    }

    pub fn _get_id(self: *const Bush) i32 {
        return self.id;
    }

    pub fn get_texture(self: *const Bush) i32 {
        return self.tex;
    }

    pub fn tick(self: *const Bush, level: *Level, x: i32, y: i32, z: i32) void {
        const below = level.get_tile(x, y - 1, z);
        if (!level.is_lit(x, y, z) or below != TileFile.dirt.get_id() and below != TileFile.grass.get_id()) {
            _ = level.set_tile(x, y, z, 0);
        }

        _ = self;
    }

    pub fn render(self: *const Bush, t: *Tesselator, level: *Level, layer: i32, x: i32, y: i32, z: i32) void {
        if (level.is_lit(x, y, z) ^ (layer != 1)) return;

        const tex: i32 = self.get_texture();

        const um0 = @as(f32, @floatFromInt(@rem(tex, 16))) / 16.0;
        const um1 = um0 + 0.999 / 16.0;
        const v0 = @as(f32, @floatFromInt(@divTrunc(tex, 16))) / 16.0;
        const v1 = v0 + 0.999 / 16.0;
        const rots: u8 = 2;

        t.color(1.0, 1.0, 1.0);

        for (0..rots) |r| {
            const rd: f64 = @floatFromInt(r);
            const rots_d: f64 = @floatFromInt(rots);

            const xa: f32 = @floatCast(@sin(rd * std.math.pi / rots_d + std.math.pi * 0.25) * 0.5);
            const za: f32 = @floatCast(@cos(rd * std.math.pi / rots_d + std.math.pi * 0.25) * 0.5);

            const x0: f32 = @as(f32, @floatFromInt(x)) + 0.5 - xa;
            const x1: f32 = @as(f32, @floatFromInt(x)) + 0.5 + xa;
            const y0: f32 = @as(f32, @floatFromInt(y)) + 0.0;
            const y1: f32 = @as(f32, @floatFromInt(y)) + 1.0;
            const z0: f32 = @as(f32, @floatFromInt(z)) + 0.5 - za;
            const z1: f32 = @as(f32, @floatFromInt(z)) + 0.5 + za;

            t.vertex_uv(x0, y1, z0, um1, v0);
            t.vertex_uv(x1, y1, z1, um0, v0);
            t.vertex_uv(x1, y0, z1, um0, v1);
            t.vertex_uv(x0, y0, z0, um1, v1);
            t.vertex_uv(x1, y1, z1, um0, v0);
            t.vertex_uv(x0, y1, z0, um1, v0);
            t.vertex_uv(x0, y0, z0, um1, v1);
            t.vertex_uv(x1, y0, z1, um0, v1);
        }
    }

    pub fn get_aabb(self: *const Bush) ?AABB {
        _ = self;
        return null;
    }

    pub fn _blocks_light(self: *const Bush) bool {
        _ = self;
        return false;
    }

    pub fn _is_solid(self: *const Bush) bool {
        _ = self;
        return false;
    }
};
