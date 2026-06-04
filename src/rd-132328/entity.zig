const std = @import("std");
const glfw = @import("glfw");

const AABB = @import("phys/aabb.zig").AABB;
const Level = @import("level/level.zig").Level;

pub const Entity = struct {
    level: *Level,

    xo: f32,
    yo: f32,
    zo: f32,

    x: f32,
    y: f32,
    z: f32,

    xd: f32,
    yd: f32,
    zd: f32,

    y_rot: f32,
    x_rot: f32,

    bb: AABB,

    on_ground: bool,
    height_offset: f32,

    pub fn new(level: *Level, rand: *std.Random) Entity {
        var self = Entity{
            .level = level,

            .xo = 0,
            .yo = 0,
            .zo = 0,

            .x = 0,
            .y = 0,
            .z = 0,

            .xd = 0,
            .yd = 0,
            .zd = 0,

            .y_rot = 0,
            .x_rot = 0,

            .bb = undefined,

            .on_ground = false,
            .height_offset = 0.0,
        };

        self.reset_pos(rand);

        return self;
    }

    pub fn reset_pos(self: *Entity, rand: *std.Random) void {
        const x: f32 = rand.float(f32) * @as(f32, @floatFromInt(self.level.width));
        const y: f32 = @as(f32, @floatFromInt(self.level.depth)) + 10;
        const z: f32 = rand.float(f32) * @as(f32, @floatFromInt(self.level.height));
        self.set_pos(x, y, z);
    }

    fn set_pos(self: *Entity, x: f32, y: f32, z: f32) void {
        self.x = x;
        self.y = y;
        self.z = z;

        const w: f32 = 0.3;
        const h: f32 = 0.9;

        self.bb = .{ .x0 = x - w, .y0 = y - h, .z0 = z - w, .x1 = x + w, .y1 = y + h, .z1 = z + w };
    }

    pub fn turn(self: *Entity, xo: f32, yo: f32) void {
        self.y_rot = @floatCast(@as(f64, self.y_rot) + @as(f64, xo) * 0.15);
        self.x_rot = @floatCast(@as(f64, self.x_rot) + @as(f64, yo) * 0.15);
        if (self.x_rot < -90.0) {
            self.x_rot = -90.0;
        }
        if (self.x_rot > 90.0) {
            self.x_rot = 90.0;
        }
    }

    pub fn tick(self: *Entity) !void {
        self.xo = self.x;
        self.yo = self.y;
        self.zo = self.z;
    }

    pub fn move(self: *Entity, alloc: std.mem.Allocator, xa: f32, ya: f32, za: f32) !void {
        var c = self.bb.expand(xa, ya, za);
        const aABBs = try self.level.get_cubes(alloc, &c);

        var nya: f32 = ya;
        var nxa: f32 = xa;
        var nza: f32 = za;

        for (aABBs.items) |*aABB| {
            nya = aABB.clip_y_collide(&self.bb, nya);
        }
        self.bb.move(0.0, nya, 0.0);

        for (aABBs.items) |*aABB| {
            nxa = aABB.clip_x_collide(&self.bb, nxa);
        }
        self.bb.move(nxa, 0.0, 0.0);

        for (aABBs.items) |*aABB| {
            nza = aABB.clip_z_collide(&self.bb, nza);
        }
        self.bb.move(0.0, 0.0, nza);

        self.on_ground = ya != nya and ya < 0.0;

        if (xa != nxa) {
            self.xd = 0.0;
        }
        if (ya != nya) {
            self.yd = 0.0;
        }
        if (za != nza) {
            self.zd = 0.0;
        }

        self.x = (self.bb.x0 + self.bb.x1) / 2.0;
        self.y = self.bb.y0 + self.height_offset;
        self.z = (self.bb.z0 + self.bb.z1) / 2.0;
    }

    pub fn move_relative(self: *Entity, xa: f32, za: f32, speed: f32) void {
        const dist = xa * xa + za * za;

        if (dist < 0.01) return;

        const dist64: f64 = @floatCast(dist);
        const delta = speed / @as(f32, @floatCast(@sqrt(dist64)));
        const xdelta = xa * delta;
        const zdelta = za * delta;

        const sin = @as(f32, @floatCast(@sin(@as(f64, self.y_rot) * std.math.pi / 180.0)));
        const cos = @as(f32, @floatCast(@cos(@as(f64, self.y_rot) * std.math.pi / 180.0)));

        self.xd += xdelta * cos - zdelta * sin;
        self.zd += zdelta * cos + xdelta * sin;
    }
};
