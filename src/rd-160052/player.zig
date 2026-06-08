const std = @import("std");
const glfw = @import("glfw");

const AABB = @import("phys/aabb.zig").AABB;
const Level = @import("level/level.zig").Level;
const Entity = @import("entity.zig").Entity;

pub const Player = struct {
    entity: Entity,

    pub fn new(level: *Level, rand: *std.Random) Player {
        var self = Player{
            .entity = Entity.new(level, rand),
        };

        self.entity.height_offset = 1.62;

        return self;
    }

    fn reset_pos(self: *Player, rand: *std.Random) void {
        self.entity.reset_pos(rand);
    }

    pub fn turn(self: *Player, xo: f32, yo: f32) void {
        self.entity.turn(xo, yo);
    }

    pub fn tick(self: *Player, window: *glfw.Window, alloc: std.mem.Allocator, rand: *std.Random) !void {
        var entity: *Entity = &self.entity;

        entity.xo = entity.x;
        entity.yo = entity.y;
        entity.zo = entity.z;

        var xa: f32 = 0.0;
        var ya: f32 = 0.0;

        if (glfw.getKey(window, .r) == .press) {
            self.reset_pos(rand);
        }

        if (glfw.getKey(window, .up) == .press or glfw.getKey(window, .w) == .press) {
            ya -= 1;
        }
        if (glfw.getKey(window, .down) == .press or glfw.getKey(window, .s) == .press) {
            ya += 1;
        }

        if (glfw.getKey(window, .left) == .press or glfw.getKey(window, .a) == .press) {
            xa -= 1;
        }
        if (glfw.getKey(window, .right) == .press or glfw.getKey(window, .d) == .press) {
            xa += 1;
        }

        if ((glfw.getKey(window, .space) == .press or glfw.getKey(window, .left_super) == .press) and entity.on_ground) {
            entity.yd = 0.5;
        }

        entity.move_relative(xa, ya, if (entity.on_ground) 0.1 else 0.02);
        entity.yd = @as(f32, @floatCast(@as(f64, entity.yd) - 0.08));

        try self.move(alloc, entity.xd, entity.yd, entity.zd);
        entity.xd *= 0.91;
        entity.yd *= 0.98;
        entity.zd *= 0.91;

        if (entity.on_ground) {
            entity.xd *= 0.7;
            entity.zd *= 0.7;
        }
    }

    pub fn move(self: *Player, alloc: std.mem.Allocator, xa: f32, ya: f32, za: f32) !void {
        try self.entity.move(alloc, xa, ya, za);
    }

    pub fn move_relative(self: *Player, xa: f32, za: f32, speed: f32) void {
        self.entity.move_relative(xa, za, speed);
    }
};
