const Vec3 = @import("vec3.zig").Vec3;

pub const Vertex = struct {
    pos: Vec3,
    u: f32,
    v: f32,

    pub fn new(x: f32, y: f32, z: f32, u: f32, v: f32) Vertex {
        return Vertex{
            .pos = Vec3{
                .x = x,
                .y = y,
                .z = z,
            },
            .u = u,
            .v = v,
        };
    }

    pub fn remap(self: *Vertex, u: f32, v: f32) Vertex {
        return Vertex{ .pos = self.pos, .u = u, .v = v };
    }
};
