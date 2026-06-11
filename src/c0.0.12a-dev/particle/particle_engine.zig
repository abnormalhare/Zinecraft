const std = @import("std");
const gl = @import("gl");

const Level = @import("../level/level.zig").Level;
const Particle = @import("particle.zig").Particle;
const Player = @import("../player.zig").Player;

const Textures = @import("../render/textures.zig").Textures;
const TesselatorFile = @import("../render/tesselator.zig");

pub const ParticleEngine = struct {
    level: *Level,
    particles: std.ArrayList(Particle),
    alloc: std.mem.Allocator,

    textures: *Textures,

    pub fn new(alloc: std.mem.Allocator, level: *Level, textures: *Textures) ParticleEngine {
        return ParticleEngine{
            .level = level,
            .particles = .empty,
            .alloc = alloc,
            .textures = textures,
        };
    }

    pub fn deinit(self: *ParticleEngine) void {
        self.particles.deinit(self.alloc);
    }

    pub fn add(self: *ParticleEngine, p: Particle) !void {
        try self.particles.append(self.alloc, p);
    }

    pub fn tick(self: *ParticleEngine) !void {
        var i: usize = 0;
        while (i < self.particles.items.len) {
            var p = &self.particles.items[i];
            try p.tick(self.alloc);
            if (p.entity.removed) {
                _ = self.particles.swapRemove(i);
            } else {
                i += 1;
            }
        }
    }

    pub fn render(self: *ParticleEngine, player: *Player, a: f32, layer: i32) !void {
        if (self.particles.items.len == 0) return;

        gl.glEnable(gl.GL_TEXTURE_2D);

        const id = try self.textures.load_texture("terrain.png", gl.GL_NEAREST);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(id));

        const xa: f32 = -@as(f32, @floatCast(@cos(std.math.degreesToRadians(@as(f64, player.entity.y_rot)))));
        const za: f32 = -@as(f32, @floatCast(@sin(std.math.degreesToRadians(@as(f64, player.entity.y_rot)))));

        const xa2: f32 = -za * @as(f32, @floatCast(@sin(std.math.degreesToRadians(@as(f64, player.entity.x_rot)))));
        const za2: f32 = xa * @as(f32, @floatCast(@sin(std.math.degreesToRadians(@as(f64, player.entity.x_rot)))));

        const ya: f32 = @floatCast(@cos(std.math.degreesToRadians(@as(f64, player.entity.x_rot))));

        const t = &TesselatorFile.instance;

        gl.glColor4f(0.8, 0.8, 0.8, 1.0);
        t.init();

        for (self.particles.items) |*p| {
            if (p.is_lit() ^ (layer == 1)) {
                p.render(t, a, xa, ya, za, xa2, za2);
            }
        }

        t.flush();
        gl.glDisable(gl.GL_TEXTURE_2D);
    }
};
