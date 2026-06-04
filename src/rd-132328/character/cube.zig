const std = @import("std");
const gl = @import("gl");

const Vertex = @import("vertex.zig").Vertex;
const Polygon = @import("polygon.zig").Polygon;

pub const Cube = struct {
    vertices: [8]Vertex,
    polygons: [6]Polygon,

    x_tex_offs: i32,
    y_tex_offs: i32,

    x: f32,
    y: f32,
    z: f32,

    x_rot: f32,
    y_rot: f32,
    z_rot: f32,

    pub fn new(x_tex_offs: i32, y_tex_offs: i32) Cube {
        return Cube{
            .vertices = std.mem.zeroes([8]Vertex),
            .polygons = std.mem.zeroes([6]Polygon),

            .x_tex_offs = x_tex_offs,
            .y_tex_offs = y_tex_offs,

            .x = 0,
            .y = 0,
            .z = 0,

            .x_rot = 0,
            .y_rot = 0,
            .z_rot = 0,
        };
    }

    pub fn add_box(self: *Cube, x0: f32, y0: f32, z0: f32, w: i32, h: i32, d: i32) void {
        const x1 = x0 + @as(f32, @floatFromInt(w));
        const y1 = y0 + @as(f32, @floatFromInt(h));
        const z1 = z0 + @as(f32, @floatFromInt(d));

        const up0 = Vertex.new(x0, y0, z0, 0.0, 0.0);
        const up1 = Vertex.new(x1, y0, z0, 0.0, 8.0);
        const up2 = Vertex.new(x1, y1, z0, 8.0, 8.0);
        const up3 = Vertex.new(x0, y1, z0, 8.0, 0.0);
        const lo0 = Vertex.new(x0, y0, z1, 0.0, 0.0);
        const lo1 = Vertex.new(x1, y0, z1, 0.0, 8.0);
        const lo2 = Vertex.new(x1, y1, z1, 8.0, 8.0);
        const lo3 = Vertex.new(x0, y1, z1, 8.0, 0.0);

        self.vertices[0] = up0;
        self.vertices[1] = up1;
        self.vertices[2] = up2;
        self.vertices[3] = up3;
        self.vertices[4] = lo0;
        self.vertices[5] = lo1;
        self.vertices[6] = lo2;
        self.vertices[7] = lo3;

        self.polygons[0] = Polygon.new_uv(
            .{ lo1, up1, up2, lo2 },
            self.x_tex_offs + d + w,
            self.y_tex_offs + d,
            self.x_tex_offs + d + w + d,
            self.y_tex_offs + d + h,
        );
        self.polygons[1] = Polygon.new_uv(
            .{ up0, lo0, lo3, up3 },
            self.x_tex_offs + 0,
            self.y_tex_offs + d,
            self.x_tex_offs + d,
            self.y_tex_offs + d + h,
        );
        self.polygons[2] = Polygon.new_uv(
            .{ lo1, lo0, up0, up1 },
            self.x_tex_offs + d,
            self.y_tex_offs + 0,
            self.x_tex_offs + d + w,
            self.y_tex_offs + d,
        );
        self.polygons[3] = Polygon.new_uv(
            .{ up2, up3, lo3, lo2 },
            self.x_tex_offs + d + w,
            self.y_tex_offs + 0,
            self.x_tex_offs + d + w + w,
            self.y_tex_offs + d,
        );
        self.polygons[4] = Polygon.new_uv(
            .{ up1, up0, up3, up2 },
            self.x_tex_offs + d,
            self.y_tex_offs + d,
            self.x_tex_offs + d + w,
            self.y_tex_offs + d + h,
        );
        self.polygons[5] = Polygon.new_uv(
            .{ lo0, lo1, lo2, lo3 },
            self.x_tex_offs + d + w + d,
            self.y_tex_offs + d,
            self.x_tex_offs + d + w + d + w,
            self.y_tex_offs + d + h,
        );
    }

    pub fn set_pos(self: *Cube, x: f32, y: f32, z: f32) void {
        self.x = x;
        self.y = y;
        self.z = z;
    }

    pub fn render(self: *Cube) void {
        gl.glPushMatrix();
        gl.glTranslatef(self.x, self.y, self.z);
        gl.glRotatef(std.math.radiansToDegrees(self.z_rot), 0.0, 0.0, 1.0);
        gl.glRotatef(std.math.radiansToDegrees(self.y_rot), 0.0, 1.0, 0.0);
        gl.glRotatef(std.math.radiansToDegrees(self.x_rot), 1.0, 0.0, 0.0);

        gl.glBegin(gl.GL_QUADS);
        for (&self.polygons) |*polygon| {
            polygon.render();
        }
        gl.glEnd();

        gl.glPopMatrix();
    }
};
