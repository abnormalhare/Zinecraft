const std = @import("std");
const gl = @import("gl");

const Level = @import("../level/level.zig").Level;
const BaseEntity = @import("../entity.zig").BaseEntity;
const Cube = @import("cube.zig").Cube;
const ZombieModel = @import("zombie_model.zig").ZombieModel;

const Textures = @import("../render/textures.zig").Textures;

var zombie_model = ZombieModel.new();

pub const Zombie = struct {
    entity: BaseEntity,

    rot: f32,
    time_offs: f32,
    speed: f32,
    rot_a: f32,

    textures: *Textures,

    pub fn new(level: *Level, rand: *std.Random, textures: *Textures, x: f32, y: f32, z: f32) Zombie {
        var entity: BaseEntity = .new(level, rand);
        entity.set_pos(x, y, z);

        const time_offs = rand.float(f32) * 1239813.0;
        const rot: f32 = @floatCast(rand.float(f64) * std.math.pi * 2.0);
        const speed: f32 = 1.0;

        return Zombie{
            .entity = entity,

            .rot = rot,
            .time_offs = time_offs,
            .speed = speed,
            .rot_a = @as(f32, @floatCast(rand.float(f64) + 1.0)) * 0.01,

            .textures = textures,
        };
    }

    pub fn reset_pos(self: *Zombie, rand: *std.Random) void {
        self.entity.reset_pos(rand);
    }

    pub fn remove(self: *Zombie) void {
        self.entity.remove();
    }

    pub fn turn(self: *Zombie, xo: f32, yo: f32) void {
        self.entity.turn(xo, yo);
    }

    pub fn tick(self: *Zombie, alloc: std.mem.Allocator, rand: *std.Random) !void {
        var entity = &self.entity;

        entity.xo = entity.x;
        entity.yo = entity.y;
        entity.zo = entity.z;

        if (entity.y < -100.0) {
            self.remove();
        }

        self.rot += self.rot_a;
        self.rot_a = @floatCast(@as(f64, self.rot_a) * 0.99);
        self.rot_a = @floatCast(@as(f64, self.rot_a + (rand.float(f64) - rand.float(f64)) * rand.float(f64) * rand.float(f64) * 0.08));

        const xa: f32 = @floatCast(@sin(@as(f64, self.rot)));
        const ya: f32 = @floatCast(@cos(@as(f64, self.rot)));

        if (entity.on_ground and rand.float(f64) < 0.08) {
            entity.yd = 0.5;
        }

        self.move_relative(xa, ya, if (entity.on_ground) 0.1 else 0.02);
        entity.yd = @floatCast(@as(f64, entity.yd) - 0.08);

        try self.move(alloc, entity.xd, entity.yd, entity.zd);
        entity.xd *= 0.91;
        entity.yd *= 0.98;
        entity.zd *= 0.91;

        if (entity.on_ground) {
            entity.xd *= 0.7;
            entity.zd *= 0.7;
        }
    }

    pub fn move(self: *Zombie, alloc: std.mem.Allocator, xa: f32, ya: f32, za: f32) !void {
        try self.entity.move(alloc, xa, ya, za);
    }

    pub fn move_relative(self: *Zombie, xa: f32, za: f32, speed: f32) void {
        self.entity.move_relative(xa, za, speed);
    }

    pub fn is_lit(self: *const Zombie) bool {
        return self.entity.is_lit();
    }

    pub fn render(self: *const Zombie, io: std.Io, a: f32) !void {
        const entity = &self.entity;

        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @bitCast(try self.textures.load_texture("char.png", gl.GL_NEAREST)));
        gl.glPushMatrix();

        const nano_time: i64 = @truncate(std.Io.Clock.now(.real, io).nanoseconds);
        const time: f64 = @as(f64, @floatFromInt(nano_time)) / 1.0E9 * 10.0 * @as(f64, self.speed) + @as(f64, self.time_offs);
        const size: f32 = 7.0 / 120.0;
        const yy: f32 = @floatCast(-@abs(@sin(time * 0.6662)) * 5.0 - 23.0);

        gl.glTranslatef(
            entity.xo + (entity.x - entity.xo) * a,
            entity.yo + (entity.y - entity.yo) * a,
            entity.zo + (entity.z - entity.zo) * a,
        );
        gl.glScalef(1.0, -1.0, 1.0);
        gl.glScalef(size, size, size);
        gl.glTranslatef(0.0, yy, 0.0);
        gl.glRotatef(std.math.radiansToDegrees(self.rot) + 180.0, 0.0, 1.0, 0.0);

        zombie_model.render(@floatCast(time));

        gl.glPopMatrix();
        gl.glDisable(gl.GL_TEXTURE_2D);
    }
};
