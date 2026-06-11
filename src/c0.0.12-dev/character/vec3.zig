pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn interpolate_to(self: *Vec3, t: Vec3, p: f32) Vec3 {
        const xt: f32 = self.x + (t.x - self.x) * p;
        const yt: f32 = self.y + (t.y - self.y) * p;
        const zt: f32 = self.z + (t.z - self.z) * p;

        return Vec3{ xt, yt, zt };
    }

    pub fn set(self: *Vec3, x: f32, y: f32, z: f32) void {
        self.x = x;
        self.y = y;
        self.z = z;
    }
};
