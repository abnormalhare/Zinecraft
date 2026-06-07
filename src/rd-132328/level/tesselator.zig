const std = @import("std");
const gl = @import("gl");

const MAX_VERTICES: i32 = 100000;

pub const Tesselator = struct {
    vertex_buffer: []f32,
    tex_coord_buffer: []f32,
    color_buffer: []f32,
    vertices: i32,

    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,

    has_color: bool,
    has_texture: bool,

    pub fn flush(self: *Tesselator) void {
        gl.glVertexPointer(3, gl.GL_FLOAT, 0, self.vertex_buffer.ptr);
        if (self.has_texture) {
            gl.glTexCoordPointer(2, gl.GL_FLOAT, 0, self.tex_coord_buffer.ptr);
        }
        if (self.has_color) {
            gl.glColorPointer(3, gl.GL_FLOAT, 0, self.color_buffer.ptr);
        }

        gl.glEnableClientState(gl.GL_VERTEX_ARRAY);
        if (self.has_texture) {
            gl.glEnableClientState(gl.GL_TEXTURE_COORD_ARRAY);
        }
        if (self.has_color) {
            gl.glEnableClientState(gl.GL_COLOR_ARRAY);
        }

        gl.glDrawArrays(gl.GL_QUADS, gl.GL_POINTS, self.vertices);

        gl.glDisableClientState(gl.GL_VERTEX_ARRAY);
        if (self.has_texture) {
            gl.glDisableClientState(gl.GL_TEXTURE_COORD_ARRAY);
        }
        if (self.has_color) {
            gl.glDisableClientState(gl.GL_COLOR_ARRAY);
        }

        self.vertices = 0;
    }

    pub fn init(self: *Tesselator) void {
        self.vertices = 0;
        self.has_color = false;
        self.has_texture = false;
    }

    pub fn new(alloc: std.mem.Allocator) !Tesselator {
        return Tesselator{
            .vertex_buffer = try alloc.alloc(f32, MAX_VERTICES * 3),
            .tex_coord_buffer = try alloc.alloc(f32, MAX_VERTICES * 2),
            .color_buffer = try alloc.alloc(f32, MAX_VERTICES * 3),
            .vertices = 0,

            .u = 0,
            .v = 0,
            .r = 0,
            .g = 0,
            .b = 0,

            .has_color = false,
            .has_texture = false,
        };
    }

    pub fn deinit(self: *Tesselator, alloc: std.mem.Allocator) void {
        alloc.free(self.vertex_buffer);
        alloc.free(self.tex_coord_buffer);
        alloc.free(self.color_buffer);
    }

    pub fn tex(self: *Tesselator, u: f32, v: f32) void {
        self.has_texture = true;
        self.u = u;
        self.v = v;
    }

    pub fn color(self: *Tesselator, r: f32, g: f32, b: f32) void {
        self.has_color = true;
        self.r = r;
        self.g = g;
        self.b = b;
    }

    pub fn vertex(self: *Tesselator, x: f32, y: f32, z: f32) void {
        self.vertex_buffer[@intCast(self.vertices * 3 + 0)] = x;
        self.vertex_buffer[@intCast(self.vertices * 3 + 1)] = y;
        self.vertex_buffer[@intCast(self.vertices * 3 + 2)] = z;

        if (self.has_texture) {
            self.tex_coord_buffer[@intCast(self.vertices * 2 + 0)] = self.u;
            self.tex_coord_buffer[@intCast(self.vertices * 2 + 1)] = self.v;
        }
        if (self.has_color) {
            self.color_buffer[@intCast(self.vertices * 3 + 0)] = self.r;
            self.color_buffer[@intCast(self.vertices * 3 + 1)] = self.g;
            self.color_buffer[@intCast(self.vertices * 3 + 2)] = self.b;
        }

        self.vertices += 1;
        if (self.vertices == MAX_VERTICES) {
            self.flush();
        }
    }
};
