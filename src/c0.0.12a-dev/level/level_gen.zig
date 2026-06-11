const std = @import("std");

const NoiseMap = @import("noise_map.zig").NoiseMap;
const TileFile = @import("tile/tile.zig");

pub const LevelGen = struct {
    width: i32,
    height: i32,
    depth: i32,

    rand: *std.Random,

    pub fn new(rand: *std.Random, width: i32, height: i32, depth: i32) LevelGen {
        return LevelGen{
            .width = width,
            .height = height,
            .depth = depth,

            .rand = rand,
        };
    }

    // returns alloc'd slice of w * h * d length, not contained
    pub fn generate_map(self: *LevelGen, alloc: std.mem.Allocator) ![]u8 {
        const w: usize = @intCast(self.width);
        const h: usize = @intCast(self.height);
        const d: usize = @intCast(self.depth);

        var heightmap1filter = NoiseMap.new(self.rand, 0);
        const heightmap1 = try heightmap1filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(heightmap1);

        var heightmap2filter = NoiseMap.new(self.rand, 0);
        const heightmap2 = try heightmap2filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(heightmap2);

        var cf_filter = NoiseMap.new(self.rand, 1);
        const cf = try cf_filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(cf);

        var rock_map_filter = NoiseMap.new(self.rand, 1);
        const rock_map = try rock_map_filter.read(alloc, @intCast(w), @intCast(h));
        defer alloc.free(rock_map);

        var blocks = try alloc.alloc(u8, w * h * d);

        for (0..w) |x| {
            for (0..d) |y| {
                for (0..h) |z| {
                    const dh1 = heightmap1[z * w + x];
                    const cfh = cf[z * w + x];
                    const dh2 = if (cfh < 128) dh1 else heightmap2[z * w + x];

                    const dh = @divTrunc(@max(dh1, dh2), 8) + @as(i32, @intCast(@divTrunc(d, 3)));

                    var rh = @divTrunc(rock_map[z * w + x], 8) + @as(i32, @intCast(@divTrunc(d, 3)));
                    if (rh > dh - 2) {
                        rh = dh - 2;
                    }

                    const i = (y * h + z) * w + x;

                    var id: i32 = 0;
                    if (y == dh) {
                        id = TileFile.grass.get_id();
                    }
                    if (y < dh) {
                        id = TileFile.dirt.get_id();
                    }
                    if (y <= rh) {
                        id = TileFile.rock.get_id();
                    }

                    blocks[i] = @truncate(@as(u32, @intCast(id)));
                }
            }
        }

        const count: usize = @divTrunc(@divTrunc(w * h * d, 256), 64);

        for (0..count) |_| {
            var rand_x = self.rand.float(f32) * @as(f32, @floatFromInt(w));
            var rand_y = self.rand.float(f32) * @as(f32, @floatFromInt(d));
            var rand_z = self.rand.float(f32) * @as(f32, @floatFromInt(h));

            const length: usize = @intFromFloat(self.rand.float(f32) + self.rand.float(f32) * 150.0);

            var rand_rot_x: f32 = @floatCast(self.rand.float(f64) * std.math.pi * 2.0);
            var rot_x_off: f32 = 0.0;
            var rand_rot_y: f32 = @floatCast(self.rand.float(f64) * std.math.pi * 2.0);
            var rot_y_off: f32 = 0.0;

            for (0..length) |l| {
                rand_x = @floatCast(@as(f64, rand_x) + @sin(@as(f64, rand_rot_x)) * @cos(@as(f64, rand_rot_y)));
                rand_z = @floatCast(@as(f64, rand_z) + @cos(@as(f64, rand_rot_x)) * @cos(@as(f64, rand_rot_y)));
                rand_y = @floatCast(@as(f64, rand_y) + @sin(@as(f64, rand_rot_y)));

                rand_rot_x += rot_x_off * 0.2;
                rot_x_off *= 0.9;
                rot_x_off += self.rand.float(f32) - self.rand.float(f32);

                rand_rot_y += rot_y_off * 0.2;
                rand_rot_y *= 0.5;
                rot_y_off *= 0.9;
                rot_y_off += self.rand.float(f32) - self.rand.float(f32);

                const size: f32 = @floatCast(@sin(@as(f64, @floatFromInt(l)) * std.math.pi / @as(f64, @floatFromInt(length))) * 2.5 + 1.0);

                var xx: i32 = @intFromFloat(rand_x - size);
                while (xx <= @as(i32, @intFromFloat(rand_x + size))) : (xx += 1) {
                    var yy: i32 = @intFromFloat(rand_y - size);
                    while (yy <= @as(i32, @intFromFloat(rand_y + size))) : (yy += 1) {
                        var zz: i32 = @intFromFloat(rand_z - size);
                        while (zz <= @as(i32, @intFromFloat(rand_z + size))) : (zz += 1) {
                            const xd = @as(f32, @floatFromInt(xx)) - rand_x;
                            const yd = @as(f32, @floatFromInt(yy)) - rand_y;
                            const zd = @as(f32, @floatFromInt(zz)) - rand_z;

                            const dd = xd * xd + yd * yd * 2.0 + zd * zd;
                            if (dd < size * size and xx >= 1 and yy >= 1 and zz >= 1 and xx < self.width - 1 and yy < self.depth - 1 and zz < self.height - 1) {
                                const ii: usize = @intCast((yy * self.height + zz) * self.width + xx);
                                if (blocks[ii] == TileFile.rock.get_id()) {
                                    blocks[ii] = 0;
                                }
                            }
                        }
                    }
                }
            }
        }

        return blocks;
    }
};
