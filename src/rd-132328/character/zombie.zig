const std = @import("std");
const gl = @import("gl");

const Level = @import("../level/level.zig").Level;
const Entity = @import("../entity.zig").Entity;
const Cube = @import("cube.zig").Cube;

const Textures = @import("../textures.zig");

pub const Zombie = struct {
    entity: Entity,

    head: Cube,
    body: Cube,
    arm0: Cube,
    arm1: Cube,
    leg0: Cube,
    leg1: Cube,

    rot: f32,
    time_offs: f32,
    speed: f32,
    rot_a: f32,

    pub fn new(level: *Level, rand: *std.Random, x: f32, y: f32, z: f32) Zombie {
        var entity: Entity = .new(level, rand);

        entity.x = x;
        entity.y = y;
        entity.z = z;

        const time_offs = rand.float(f32) * 1239813.0;
        const rot: f32 = @floatCast(rand.float(f64) * std.math.pi * 2.0);
        const speed: f32 = 1.0;

        var head = Cube.new(0, 0);
        head.add_box(-4.0, -8.0, -4.0, 8, 8, 8);

        var body = Cube.new(16, 16);
        body.add_box(-4.0, 0.0, -2.0, 8, 12, 4);

        var arm0 = Cube.new(40, 16);
        arm0.add_box(-3.0, -2.0, -2.0, 4, 12, 4);
        arm0.set_pos(-5.0, 2.0, 0.0);

        var arm1 = Cube.new(40, 16);
        arm1.add_box(-1.0, -2.0, -2.0, 4, 12, 4);
        arm1.set_pos(5.0, 2.0, 0.0);

        var leg0 = Cube.new(0, 16);
        leg0.add_box(-2.0, 0.0, -2.0, 4, 12, 4);
        leg0.set_pos(-2.0, 12.0, 0.0);

        var leg1 = Cube.new(0, 16);
        leg1.add_box(-2.0, 0.0, -2.0, 4, 12, 4);
        leg1.set_pos(2.0, 12.0, 0.0);

        return Zombie{
            .entity = entity,

            .head = head,
            .body = body,
            .arm0 = arm0,
            .arm1 = arm1,
            .leg0 = leg0,
            .leg1 = leg1,

            .rot = rot,
            .time_offs = time_offs,
            .speed = speed,
            .rot_a = @as(f32, @floatCast(rand.float(f64) + 1.0)) * 0.01,
        };
    }

    pub fn reset_pos(self: *Zombie, rand: *std.Random) void {
        self.entity.reset_pos(rand);
    }

    pub fn turn(self: *Zombie, xo: f32, yo: f32) void {
        self.entity.turn(xo, yo);
    }

    pub fn tick(self: *Zombie, alloc: std.mem.Allocator, rand: *std.Random) !void {
        var entity = &self.entity;

        entity.xo = entity.x;
        entity.yo = entity.y;
        entity.zo = entity.z;

        self.rot += self.rot_a;
        self.rot_a = @floatCast(@as(f64, self.rot_a) * 0.99);
        self.rot_a = @floatCast(@as(f64, self.rot_a + (rand.float(f64) - rand.float(f64)) * rand.float(f64) * rand.float(f64) * 0.01));

        const xa: f32 = @floatCast(@sin(@as(f64, self.rot)));
        const ya: f32 = @floatCast(@cos(@as(f64, self.rot)));

        if (entity.on_ground and rand.float(f64) < 0.01) {
            entity.yd = 0.12;
        }

        self.move_relative(xa, ya, if (entity.on_ground) 0.02 else 0.005);
        entity.yd = @floatCast(@as(f64, entity.yd) - 0.005);

        try self.move(alloc, entity.xd, entity.yd, entity.zd);
        entity.xd *= 0.91;
        entity.yd *= 0.98;
        entity.zd *= 0.91;

        if (entity.y > 100.0) {
            self.reset_pos(rand);
        }

        if (entity.on_ground) {
            entity.xd *= 0.8;
            entity.zd *= 0.8;
        }
    }

    pub fn move(self: *Zombie, alloc: std.mem.Allocator, xa: f32, ya: f32, za: f32) !void {
        try self.entity.move(alloc, xa, ya, za);
    }

    pub fn move_relative(self: *Zombie, xa: f32, za: f32, speed: f32) void {
        self.entity.move_relative(xa, za, speed);
    }

    pub fn render(self: *Zombie, io: std.Io, a: f32) !void {
        const entity = &self.entity;

        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @bitCast(try Textures.load_texture("char.png", gl.GL_NEAREST)));
        gl.glPushMatrix();

        const time: f64 = @as(f64, @floatFromInt(std.Io.Clock.now(.real, io).nanoseconds)) / 1.0E9 * 10.0 * @as(f64, self.speed) + @as(f64, self.time_offs);
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

        self.head.y_rot = @as(f32, @floatCast(@sin(time * 0.83)));
        self.head.x_rot = @as(f32, @floatCast(@sin(time))) * 0.8;

        self.arm0.x_rot = @as(f32, @floatCast(@sin(time * 0.6662 + std.math.pi))) * 2.0;
        self.arm0.z_rot = @as(f32, @floatCast(@sin(time * 0.2312) + 1.0));

        self.arm1.x_rot = @as(f32, @floatCast(@sin(time * 0.6662))) * 2.0;
        self.arm1.z_rot = @as(f32, @floatCast(@sin(time * 0.2812) - 1.0));

        self.leg0.x_rot = @as(f32, @floatCast(@sin(time * 0.6662))) * 1.4;
        self.leg1.x_rot = @as(f32, @floatCast(@sin(time * 0.6662 + std.math.pi))) * 1.4;

        self.head.render();
        self.body.render();
        self.arm0.render();
        self.arm1.render();
        self.leg0.render();
        self.leg1.render();

        gl.glPopMatrix();
        gl.glDisable(gl.GL_TEXTURE_2D);
    }
};
