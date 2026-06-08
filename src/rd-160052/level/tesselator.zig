const std = @import("std");
const gl = @import("gl");

const MAX_MEMORY_USE: i32 = 0x400000;
const MAX_FLOATS: i32 = 0x80000;

pub var instance: Tesselator = undefined;

pub fn init(alloc: std.mem.Allocator) !void {
    instance = try Tesselator.new(alloc);
}

pub fn deinit(alloc: std.mem.Allocator) void {
    instance.deinit(alloc);
}

pub const Tesselator = struct {
    buffer: []f32,
    vertices: i32,

    u: f32,
    v: f32,
    r: f32,
    g: f32,
    b: f32,

    has_color: bool,
    has_texture: bool,

    len: i32,
    p: i32,

    pub fn flush(self: *Tesselator) void {
        if (self.has_texture and self.has_color) {
            gl.glInterleavedArrays(gl.GL_T2F_C3F_V3F, 0, self.buffer.ptr);
        } else if (self.has_texture) {
            gl.glInterleavedArrays(gl.GL_T2F_V3F, 0, self.buffer.ptr);
        } else if (self.has_color) {
            gl.glInterleavedArrays(gl.GL_C3F_V3F, 0, self.buffer.ptr);
        } else {
            gl.glInterleavedArrays(gl.GL_V3F, 0, self.buffer.ptr);
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

        self.clear();
    }

    fn clear(self: *Tesselator) void {
        self.vertices = 0;
        self.p = 0;
    }

    pub fn init(self: *Tesselator) void {
        self.clear();
        self.has_color = false;
        self.has_texture = false;
    }

    pub fn new(alloc: std.mem.Allocator) !Tesselator {
        return Tesselator{
            .buffer = try alloc.alloc(f32, MAX_FLOATS),
            .vertices = 0,

            .u = 0,
            .v = 0,
            .r = 0,
            .g = 0,
            .b = 0,

            .has_color = false,
            .has_texture = false,

            .len = 3,
            .p = 0,
        };
    }

    pub fn deinit(self: *Tesselator, alloc: std.mem.Allocator) void {
        alloc.free(self.buffer);
    }

    pub fn tex(self: *Tesselator, u: f32, v: f32) void {
        if (!self.has_texture) {
            self.len += 2;
        }

        self.has_texture = true;
        self.u = u;
        self.v = v;
    }

    pub fn color(self: *Tesselator, r: f32, g: f32, b: f32) void {
        if (!self.has_color) {
            self.len += 3;
        }

        self.has_color = true;
        self.r = r;
        self.g = g;
        self.b = b;
    }

    pub fn vertex_uv(self: *Tesselator, x: f32, y: f32, z: f32, u: f32, v: f32) void {
        self.tex(u, v);
        self.vertex(x, y, z);
    }

    fn getp(self: *Tesselator) usize {
        const ret = self.p;
        self.p += 1;
        return @intCast(ret);
    }

    pub fn vertex(self: *Tesselator, x: f32, y: f32, z: f32) void {
        if (self.has_texture) {
            self.buffer[self.getp()] = self.u;
            self.buffer[self.getp()] = self.v;
        }

        if (self.has_color) {
            self.buffer[self.getp()] = self.r;
            self.buffer[self.getp()] = self.g;
            self.buffer[self.getp()] = self.b;
        }

        self.buffer[self.getp()] = x;
        self.buffer[self.getp()] = y;
        self.buffer[self.getp()] = z;

        self.vertices += 1;
        if (self.p >= MAX_FLOATS - self.len) {
            self.flush();
        }
    }
};
