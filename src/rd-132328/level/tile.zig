const Tesselator = @import("tesselator.zig").Tesselator;
const Level = @import("level.zig").Level;

pub var rock: Tile = .init(0);
pub var grass: Tile = .init(1);

pub const Tile = struct {
    tex: i32,

    fn init(tex: i32) Tile {
        return Tile{ .tex = tex };
    }

    pub fn render(self: *Tile, t: *Tesselator, level: *Level, layer: i32, x: i32, y: i32, z: i32) void {
        const um0 = @as(f32, @floatFromInt(self.tex)) / 16.0;
        const um1 = um0 + 0.999 / 16.0;
        const v0 = 0.0;
        const v1 = v0 + 0.999 / 16.0;

        const c1: f32 = 1.0;
        const c2: f32 = 0.8;
        const c3: f32 = 0.6;

        const x0: f32 = @as(f32, @floatFromInt(x)) + 0.0;
        const x1: f32 = @as(f32, @floatFromInt(x)) + 1.0;
        const y0: f32 = @as(f32, @floatFromInt(y)) + 0.0;
        const y1: f32 = @as(f32, @floatFromInt(y)) + 1.0;
        const z0: f32 = @as(f32, @floatFromInt(z)) + 0.0;
        const z1: f32 = @as(f32, @floatFromInt(z)) + 1.0;

        if (!level.is_solid_tile(x, y - 1, z)) {
            const br = level.get_brightness(x, y - 1, z) * c1;
            if ((br == c1) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um0, v1);
                t.vertex(x0, y0, z1);
                t.tex(um0, v0);
                t.vertex(x0, y0, z0);
                t.tex(um1, v0);
                t.vertex(x1, y0, z0);
                t.tex(um1, v1);
                t.vertex(x1, y0, z1);
            }
        }

        if (!level.is_solid_tile(x, y + 1, z)) {
            const br = level.get_brightness(x, y, z) * c1;
            if ((br == c1) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um1, v1);
                t.vertex(x1, y1, z1);
                t.tex(um1, v0);
                t.vertex(x1, y1, z0);
                t.tex(um0, v0);
                t.vertex(x0, y1, z0);
                t.tex(um0, v1);
                t.vertex(x0, y1, z1);
            }
        }

        if (!level.is_solid_tile(x, y, z - 1)) {
            const br = level.get_brightness(x, y, z - 1) * c2;
            if ((br == c2) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um1, v0);
                t.vertex(x0, y1, z0);
                t.tex(um0, v0);
                t.vertex(x1, y1, z0);
                t.tex(um0, v1);
                t.vertex(x1, y0, z0);
                t.tex(um1, v1);
                t.vertex(x0, y0, z0);
            }
        }

        if (!level.is_solid_tile(x, y, z + 1)) {
            const br = level.get_brightness(x, y, z + 1) * c2;
            if ((br == c2) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um0, v0);
                t.vertex(x0, y1, z1);
                t.tex(um0, v1);
                t.vertex(x0, y0, z1);
                t.tex(um1, v1);
                t.vertex(x1, y0, z1);
                t.tex(um1, v0);
                t.vertex(x1, y1, z1);
            }
        }

        if (!level.is_solid_tile(x - 1, y, z)) {
            const br = level.get_brightness(x - 1, y, z) * c3;
            if ((br == c3) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um1, v0);
                t.vertex(x0, y1, z1);
                t.tex(um0, v0);
                t.vertex(x0, y1, z0);
                t.tex(um0, v1);
                t.vertex(x0, y0, z0);
                t.tex(um1, v1);
                t.vertex(x0, y0, z1);
            }
        }

        if (!level.is_solid_tile(x + 1, y, z)) {
            const br = level.get_brightness(x + 1, y, z) * c3;
            if ((br == c3) ^ (layer == 1)) {
                t.color(br, br, br);
                t.tex(um0, v1);
                t.vertex(x1, y0, z1);
                t.tex(um1, v1);
                t.vertex(x1, y0, z0);
                t.tex(um1, v0);
                t.vertex(x1, y1, z0);
                t.tex(um0, v0);
                t.vertex(x1, y1, z1);
            }
        }
    }

    pub fn render_face(self: *Tile, t: *Tesselator, x: i32, y: i32, z: i32, face: i32) void {
        const x0: f32 = @as(f32, @floatFromInt(x)) + 0.0;
        const x1: f32 = @as(f32, @floatFromInt(x)) + 1.0;
        const y0: f32 = @as(f32, @floatFromInt(y)) + 0.0;
        const y1: f32 = @as(f32, @floatFromInt(y)) + 1.0;
        const z0: f32 = @as(f32, @floatFromInt(z)) + 0.0;
        const z1: f32 = @as(f32, @floatFromInt(z)) + 1.0;

        switch (face) {
            0 => {
                t.vertex(x0, y0, z1);
                t.vertex(x0, y0, z0);
                t.vertex(x1, y0, z0);
                t.vertex(x1, y0, z1);
            },
            1 => {
                t.vertex(x1, y1, z1);
                t.vertex(x1, y1, z0);
                t.vertex(x0, y1, z0);
                t.vertex(x0, y1, z1);
            },
            2 => {
                t.vertex(x0, y1, z0);
                t.vertex(x1, y1, z0);
                t.vertex(x1, y0, z0);
                t.vertex(x0, y0, z0);
            },
            3 => {
                t.vertex(x0, y1, z1);
                t.vertex(x0, y0, z1);
                t.vertex(x1, y0, z1);
                t.vertex(x1, y1, z1);
            },
            4 => {
                t.vertex(x0, y1, z1);
                t.vertex(x0, y1, z0);
                t.vertex(x0, y0, z0);
                t.vertex(x0, y0, z1);
            },
            5 => {
                t.vertex(x1, y0, z1);
                t.vertex(x1, y0, z0);
                t.vertex(x1, y1, z0);
                t.vertex(x1, y1, z1);
            },
            else => return, // maybe error?
        }

        _ = self;
    }
};
