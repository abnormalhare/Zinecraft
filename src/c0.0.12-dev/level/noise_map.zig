const std = @import("std");

pub const NoiseMap = struct {
    rand: *std.Random,
    seed: i32,
    levels: i32,
    fuzz: i32,

    pub fn new(rand: *std.Random, levels: i32) NoiseMap {
        return NoiseMap{
            .rand = rand,
            .seed = rand.int(i32),
            .levels = levels,
            .fuzz = 16,
        };
    }

    // returns alloc'd int with size [width * height], not contained
    pub fn read(self: *NoiseMap, alloc: std.mem.Allocator, width: i32, height: i32) ![]i32 {
        var tmp: []i32 = try alloc.alloc(i32, @intCast(width * height));
        defer alloc.free(tmp);

        const level: u5 = @truncate(@as(u32, @intCast(self.levels)));
        const result = width >> level;

        var y: i32 = 0;
        while (y < height) : (y += result) {
            var x: i32 = 0;
            while (x < width) : (x += result) {
                const idx: usize = @intCast(y * width + x);

                tmp[idx] = @as(i32, self.rand.int(i8)) * self.fuzz;
            }
        }

        var res = width >> level;
        while (res > 1) : (res = @divTrunc(res, 2)) {
            const cy = 256 * (res << level);
            const cx = @divTrunc(res, 2);

            var y1: i32 = 0;
            while (y1 < height) : (y1 += res) {
                var x1: i32 = 0;
                while (x1 < width) : (x1 += res) {
                    const c = tmp[@intCast(@rem(x1 + 0, width) + @rem(y1 + 0, height) * width)];
                    const r = tmp[@intCast(@rem(x1 + res, width) + @rem(y1 + 0, height) * width)];
                    const d = tmp[@intCast(@rem(x1 + 0, width) + @rem(y1 + res, height) * width)];
                    const mu = tmp[@intCast(@rem(x1 + res, width) + @rem(y1 + res, height) * width)];

                    const ml = @divTrunc(c + d + r + mu, 4) + self.rand.intRangeAtMost(i32, 0, cy * 2 - 1) - cy;
                    tmp[@intCast((y1 + cx) * width + x1 + cx)] = ml;
                }
            }

            y1 = 0;
            while (y1 < height) : (y1 += res) {
                var x1: i32 = 0;
                while (x1 < width) : (x1 += res) {
                    const c = tmp[@intCast(y1 * width + x1)];
                    const r = tmp[@intCast(@rem(x1 + res, width) + y1 * width)];
                    const d = tmp[@intCast(x1 + @rem(y1 + res, width) * width)];
                    const mu = tmp[@intCast((x1 + cx & width - 1) + (y1 + cx - res & height - 1) * width)];
                    const ml = tmp[@intCast((x1 + cx - res & width - 1) + (y1 + cx & height - 1) * width)];
                    const m = tmp[@intCast(@rem(x1 + cx, width) + @rem(y1 + cx, height) * width)];

                    const u = @divTrunc(c + r + m + mu, 4) + self.rand.intRangeAtMost(i32, 0, cy * 2 - 1) - cy;
                    const l = @divTrunc(c + d + m + ml, 4) + self.rand.intRangeAtMost(i32, 0, cy * 2 - 1) - cy;

                    tmp[@intCast(x1 + cx + y1 * width)] = u;
                    tmp[@intCast(x1 + (y1 + cx) * width)] = l;
                }
            }
        }

        var out = try alloc.alloc(i32, @intCast(width * height));

        const h: usize = @intCast(height);
        const w: usize = @intCast(width);

        for (0..h) |y2| {
            for (0..w) |x2| {
                out[y2 * w + x2] = @divTrunc(tmp[y2 % h * w + x2 % w], 512) + 128;
            }
        }

        return out;
    }
};
