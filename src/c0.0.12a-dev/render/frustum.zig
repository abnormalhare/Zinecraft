const gl = @import("gl");

const AABB = @import("../phys/aabb.zig").AABB;

pub const RIGHT: i32 = 0;
pub const LEFT: i32 = 1;
pub const BOTTOM: i32 = 2;
pub const TOP: i32 = 3;
pub const BACK: i32 = 4;
pub const FRONT: i32 = 5;

pub const A = 0;
pub const B = 1;
pub const C = 2;
pub const D = 3;

var the_frustum: Frustum = Frustum.new();

pub const Frustum = struct {
    frustum: [6][4]f32,

    proj: [16]f32,
    modl: [16]f32,
    clip: [16]f32,

    fn new() Frustum {
        return Frustum{
            .frustum = .{.{0} ** 4} ** 6,

            .proj = .{0} ** 16,
            .modl = .{0} ** 16,
            .clip = .{0} ** 16,
        };
    }

    pub fn get_frustum() *Frustum {
        the_frustum.calculate_frustum();
        return &the_frustum;
    }

    fn normalize_plane(self: *Frustum, frustum: [][4]f32, side: i32) void {
        const uside: usize = @intCast(side);
        const magnitude: f32 = @sqrt(frustum[uside][A] * frustum[uside][A] + frustum[uside][B] * frustum[uside][B] + frustum[uside][C] * frustum[uside][C]);
        frustum[uside][A] /= magnitude;
        frustum[uside][B] /= magnitude;
        frustum[uside][C] /= magnitude;
        frustum[uside][D] /= magnitude;

        _ = self;
    }

    fn calculate_frustum(self: *Frustum) void {
        gl.glGetFloatv(gl.GL_PROJECTION_MATRIX, &self.proj);
        gl.glGetFloatv(gl.GL_MODELVIEW_MATRIX, &self.modl);

        for (0..4) |i| {
            for (0..4) |j| {
                const clip = i * 4 + j;
                const modl = i * 4;

                self.clip[clip] =
                    self.modl[modl + 0] * self.proj[j + 0] +
                    self.modl[modl + 1] * self.proj[j + 4] +
                    self.modl[modl + 2] * self.proj[j + 8] +
                    self.modl[modl + 3] * self.proj[j + 12];
            }
        }

        self.frustum[RIGHT][A] = self.clip[3] - self.clip[0];
        self.frustum[RIGHT][B] = self.clip[7] - self.clip[4];
        self.frustum[RIGHT][C] = self.clip[11] - self.clip[8];
        self.frustum[RIGHT][D] = self.clip[15] - self.clip[12];
        self.normalize_plane(&self.frustum, 0);

        self.frustum[LEFT][A] = self.clip[3] + self.clip[0];
        self.frustum[LEFT][B] = self.clip[7] + self.clip[4];
        self.frustum[LEFT][C] = self.clip[11] + self.clip[8];
        self.frustum[LEFT][D] = self.clip[15] + self.clip[12];
        self.normalize_plane(&self.frustum, 1);

        self.frustum[BOTTOM][A] = self.clip[3] + self.clip[1];
        self.frustum[BOTTOM][B] = self.clip[7] + self.clip[5];
        self.frustum[BOTTOM][C] = self.clip[11] + self.clip[9];
        self.frustum[BOTTOM][D] = self.clip[15] + self.clip[13];
        self.normalize_plane(&self.frustum, 2);

        self.frustum[TOP][A] = self.clip[3] - self.clip[1];
        self.frustum[TOP][B] = self.clip[7] - self.clip[5];
        self.frustum[TOP][C] = self.clip[11] - self.clip[9];
        self.frustum[TOP][D] = self.clip[15] - self.clip[13];
        self.normalize_plane(&self.frustum, 3);

        self.frustum[BACK][A] = self.clip[3] - self.clip[2];
        self.frustum[BACK][B] = self.clip[7] - self.clip[6];
        self.frustum[BACK][C] = self.clip[11] - self.clip[10];
        self.frustum[BACK][D] = self.clip[15] - self.clip[14];
        self.normalize_plane(&self.frustum, 4);

        self.frustum[FRONT][A] = self.clip[3] + self.clip[2];
        self.frustum[FRONT][B] = self.clip[7] + self.clip[6];
        self.frustum[FRONT][C] = self.clip[11] + self.clip[10];
        self.frustum[FRONT][D] = self.clip[15] + self.clip[14];
        self.normalize_plane(&self.frustum, 5);
    }

    pub fn point_in_frustum(self: *Frustum, x: f32, y: f32, z: f32) bool {
        for (0..6) |i| {
            if (self.frustum[i][A] * x + self.frustum[i][B] * y + self.frustum[i][C] * z + self.frustum[i][D] <= 0.0) {
                return false;
            }
        }

        return true;
    }

    pub fn sphere_in_frustum(self: *Frustum, x: f32, y: f32, z: f32, radius: f32) bool {
        for (0..6) |i| {
            if (self.frustum[i][A] * x + self.frustum[i][B] * y + self.frustum[i][C] * z + self.frustum[i][D] <= -radius) {
                return false;
            }
        }

        return true;
    }

    pub fn cube_fully_in_frustrum(self: *Frustum, x1: f32, y1: f32, z1: f32, x2: f32, y2: f32, z2: f32) bool {
        for (0..6) |i| {
            if (self.frustum[i][A] * x1 + self.frustum[i][B] * y1 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x2 + self.frustum[i][B] * y1 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x1 + self.frustum[i][B] * y2 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x2 + self.frustum[i][B] * y2 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x1 + self.frustum[i][B] * y1 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x2 + self.frustum[i][B] * y1 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x1 + self.frustum[i][B] * y2 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0) return false;
            if (self.frustum[i][A] * x2 + self.frustum[i][B] * y2 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0) return false;
        }

        return true;
    }

    pub fn cube_in_frustum(self: *Frustum, x1: f32, y1: f32, z1: f32, x2: f32, y2: f32, z2: f32) bool {
        for (0..6) |i| {
            if (self.frustum[i][A] * x1 + self.frustum[i][B] * y1 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x2 + self.frustum[i][B] * y1 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x1 + self.frustum[i][B] * y2 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x2 + self.frustum[i][B] * y2 + self.frustum[i][C] * z1 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x1 + self.frustum[i][B] * y1 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x2 + self.frustum[i][B] * y1 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x1 + self.frustum[i][B] * y2 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0 and
                self.frustum[i][A] * x2 + self.frustum[i][B] * y2 + self.frustum[i][C] * z2 + self.frustum[i][D] <= 0.0)
            {
                return false;
            }
        }

        return true;
    }

    pub fn is_visible(self: *Frustum, aabb: AABB) bool {
        return self.cube_in_frustum(aabb.x0, aabb.y0, aabb.z0, aabb.x1, aabb.y1, aabb.z1);
    }
};
