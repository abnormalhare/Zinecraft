const std = @import("std");

const Level = @import("../level/level.zig").Level;
const Entity = @import("../entity.zig").Entity;
const Tesselator = @import("../level/tesselator.zig").Tesselator;

pub const Particle = struct {
    entity: Entity,

    xd: f32,
    yd: f32,
    zd: f32,

    tex: i32,

    uo: f32,
    vo: f32,

    pub fn init(level: *Level, rand: *std.Random, x: f32, y: f32, z: f32, xa: f32, ya: f32, za: f32, tex: i32) Particle {
        var entity: Entity = .new(level, rand);

        entity.set_size(0.2, 0.2);
        entity.height_offset = entity.bb_height / 2.0;
        entity.set_pos(x, y, z);

        const xd: f32 = xa + @as(f32, @floatCast(rand.float(f64) * 2.0 - 1.0)) * 0.4;
        const yd: f32 = ya + @as(f32, @floatCast(rand.float(f64) * 2.0 - 1.0)) * 0.4;
        const zd: f32 = za + @as(f32, @floatCast(rand.float(f64) * 2.0 - 1.0)) * 0.4;

        const speed: f32 = @as(f32, @floatCast(rand.float(f64) * rand.float(f64) + 1.0)) * 0.15;
        const dd: f32 = @floatCast(@sqrt(@as(f64, xd * xd + yd * yd + zd * zd)));

        return Particle{
            .entity = entity,

            .xd = xd / dd * speed * 0.7,
            .yd = yd / dd * speed,
            .zd = zd / dd * speed * 0.7,

            .tex = tex,

            .uo = @as(f32, @floatCast(rand.float(f64))) * 3.0,
            .vo = @as(f32, @floatCast(rand.float(f64))) * 3.0,
        };
    }

    pub fn reset_pos(self: *Particle, rand: *std.Random) void {
        self.entity.reset_pos(rand);
    }

    pub fn remove(self: *Particle) void {
        self.entity.remove();
    }

    pub fn set_size(self: *Particle, w: f32, h: f32) void {
        self.entity.set_size(w, h);
    }

    pub fn set_pos(self: *Particle, x: f32, y: f32, z: f32) void {
        self.entity.set_pos(x, y, z);
    }

    pub fn turn(self: *Particle, xo: f32, yo: f32) void {
        self.entity.turn(xo, yo);
    }

    pub fn tick(self: *Particle, alloc: std.mem.Allocator, rand: *std.Random) !void {
        const entity = &self.entity;

        entity.xo = entity.x;
        entity.yo = entity.y;
        entity.zo = entity.z;

        if (rand.float(f64) < 0.1) {
            self.remove();
        }

        self.yd = @floatCast(@as(f64, self.yd) - 0.06);
        try self.move(alloc, self.xd, self.yd, self.zd);

        self.xd *= 0.98;
        self.yd *= 0.98;
        self.zd *= 0.98;
        if (self.entity.on_ground) {
            self.xd *= 0.7;
            self.zd *= 0.7;
        }
    }

    pub fn move(self: *Particle, alloc: std.mem.Allocator, xa: f32, ya: f32, za: f32) !void {
        try self.entity.move(alloc, xa, ya, za);
    }

    pub fn move_relative(self: *Particle, xa: f32, za: f32, speed: f32) void {
        self.entity.move_relative(xa, za, speed);
    }

    pub fn is_lit(self: *const Particle) bool {
        return self.entity.is_lit();
    }

    pub fn render(self: *const Particle, t: *Tesselator, a: f32, xa: f32, ya: f32, za: f32) void {
        const entity = &self.entity;

        const um0: f32 = (@as(f32, @floatFromInt(@rem(self.tex, 16))) + self.uo / 4.0) / 16.0;
        const um1: f32 = um0 + 0.999 / 64.0;
        const v0: f32 = (@as(f32, @floatFromInt(@divTrunc(self.tex, 16))) + self.vo / 4.0) / 16.0;
        const v1: f32 = v0 + 0.999 / 64.0;

        const r: f32 = 0.1;
        const x: f32 = entity.xo + (entity.x - entity.xo) * a;
        const y: f32 = entity.yo + (entity.y - entity.yo) * a;
        const z: f32 = entity.zo + (entity.z - entity.zo) * a;

        t.vertex_uv(x - xa * r, y - ya * r, z - za * r, um0, v1);
        t.vertex_uv(x - xa * r, y + ya * r, z - za * r, um0, v0);
        t.vertex_uv(x + xa * r, y + ya * r, z + za * r, um1, v0);
        t.vertex_uv(x + xa * r, y - ya * r, z + za * r, um1, v1);
    }
};
