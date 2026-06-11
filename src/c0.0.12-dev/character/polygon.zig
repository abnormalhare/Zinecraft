const std = @import("std");
const gl = @import("gl");

const Vertex = @import("vertex.zig").Vertex;

pub const Polygon = struct {
    vertices: [4]Vertex, // originally unsized, but the code doesnt handle != 4 cases?
    vertex_count: i32,

    pub fn new(vertices: [4]Vertex) Polygon {
        return Polygon{
            .vertices = vertices,
            .vertex_count = vertices.len,
        };
    }

    pub fn new_uv(vertices: [4]Vertex, um0: i32, v0: i32, um1: i32, v1: i32) Polygon {
        var self = Polygon.new(vertices);

        self.vertices[0] = self.vertices[0].remap(@floatFromInt(um1), @floatFromInt(v0));
        self.vertices[1] = self.vertices[1].remap(@floatFromInt(um0), @floatFromInt(v0));
        self.vertices[2] = self.vertices[2].remap(@floatFromInt(um0), @floatFromInt(v1));
        self.vertices[3] = self.vertices[3].remap(@floatFromInt(um1), @floatFromInt(v1));

        return self;
    }

    pub fn render(self: *Polygon) void {
        gl.glColor3f(1.0, 1.0, 1.0);

        var iter = std.mem.reverseIterator(&self.vertices);

        while (iter.next()) |v| {
            gl.glTexCoord2f(v.u / 63.999, v.v / 31.999);
            gl.glVertex3f(v.pos.x, v.pos.y, v.pos.z);
        }
    }
};
