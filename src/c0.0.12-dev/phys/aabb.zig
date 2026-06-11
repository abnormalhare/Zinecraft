const epsilon: f32 = 0.0;

pub const AABB = struct {
    x0: f32,
    y0: f32,
    z0: f32,
    x1: f32,
    y1: f32,
    z1: f32,

    pub fn expand(self: *AABB, xa: f32, ya: f32, za: f32) AABB {
        var x0: f32 = self.x0;
        var y0: f32 = self.y0;
        var z0: f32 = self.z0;
        var x1: f32 = self.x1;
        var y1: f32 = self.y1;
        var z1: f32 = self.z1;

        if (xa < 0.0) {
            x0 += xa;
        }
        if (xa > 0.0) {
            x1 += xa;
        }

        if (ya < 0.0) {
            y0 += ya;
        }
        if (ya > 0.0) {
            y1 += ya;
        }

        if (za < 0.0) {
            z0 += za;
        }
        if (za > 0.0) {
            z1 += za;
        }

        return AABB{ .x0 = x0, .y0 = y0, .z0 = z0, .x1 = x1, .y1 = y1, .z1 = z1 };
    }

    pub fn grow(self: *AABB, xa: f32, ya: f32, za: f32) AABB {
        return AABB{
            .x0 = self.x0 - xa,
            .y0 = self.y0 - ya,
            .z0 = self.z0 - za,
            .x1 = self.x1 + xa,
            .y1 = self.y1 + ya,
            .z1 = self.z1 + za,
        };
    }

    pub fn clip_x_collide(self: *AABB, c: *AABB, xa: f32) f32 {
        if (c.y1 <= self.y0 or c.y0 >= self.y1) {
            return xa;
        }

        if (c.z1 <= self.z0 or c.z0 >= self.z1) {
            return xa;
        }

        var max: f32 = xa;
        if (xa > 0.0 and c.x1 <= self.x0) {
            max = @min(xa, self.x0 - c.x1 - epsilon);
        }
        if (xa < 0.0 and c.x0 >= self.x1) {
            max = @max(xa, self.x1 - c.x0 + epsilon);
        }

        return max;
    }

    pub fn clip_y_collide(self: *AABB, c: *AABB, ya: f32) f32 {
        if (c.x1 <= self.x0 or c.x0 >= self.x1) {
            return ya;
        }

        if (c.z1 <= self.z0 or c.z0 >= self.z1) {
            return ya;
        }

        var max: f32 = ya;
        if (ya > 0.0 and c.y1 <= self.y0) {
            max = @min(ya, self.y0 - c.y1 - epsilon);
        }
        if (ya < 0.0 and c.y0 >= self.y1) {
            max = @max(ya, self.y1 - c.y0 + epsilon);
        }

        return max;
    }

    pub fn clip_z_collide(self: *AABB, c: *AABB, za: f32) f32 {
        if (c.x1 <= self.x0 or c.x0 >= self.x1) {
            return za;
        }

        if (c.y1 <= self.y0 or c.y0 >= self.y1) {
            return za;
        }

        var max: f32 = za;
        if (za > 0.0 and c.z1 <= self.z0) {
            max = @min(za, self.z0 - c.z1 - epsilon);
        }
        if (za < 0.0 and c.z0 >= self.z1) {
            max = @max(za, self.z1 - c.z0 + epsilon);
        }

        return max;
    }

    pub fn intersects(self: *const AABB, c: *const AABB) bool {
        return c.x1 > self.x0 and
            c.x0 < self.x1 and
            c.y1 > self.y0 and
            c.y0 < self.y1 and
            c.z1 > self.z0 and
            c.z0 < self.z1;
    }

    pub fn move(self: *AABB, xa: f32, ya: f32, za: f32) void {
        self.x0 += xa;
        self.y0 += ya;
        self.z0 += za;
        self.x1 += xa;
        self.y1 += ya;
        self.z1 += za;
    }
};
