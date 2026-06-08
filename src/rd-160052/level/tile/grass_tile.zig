const std = @import("std");

const TileFile = @import("tile.zig");
const Tile = @import("tile.zig").Tile;
const Level = @import("../level.zig").Level;

pub const GrassTile = struct {
    tex: i32,
    id: i32,

    pub fn init(comptime id: i32) GrassTile {
        const self = GrassTile{
            .tex = 3,
            .id = id,
        };

        return self;
    }

    pub fn _get_tex(self: *const GrassTile) i32 {
        return self.tex;
    }

    pub fn _get_id(self: *const GrassTile) i32 {
        return self.id;
    }

    pub fn get_texture(self: *const GrassTile, face: i32) i32 {
        _ = self;
        return if (face == 1) 0 else if (face == 0) 2 else 3;
    }

    pub fn _blocks_light(self: *const GrassTile) bool {
        _ = self;
        return true;
    }

    pub fn _is_solid(self: *const GrassTile) bool {
        _ = self;
        return true;
    }

    pub fn tick(self: *const GrassTile, level: *Level, x: i32, y: i32, z: i32, random: *std.Random) void {
        if (!level.is_lit(x, y, z)) {
            _ = level.set_tile(x, y, z, TileFile.dirt.get_id());
            return;
        }

        for (0..4) |_| {
            const xt: i32 = x + random.intRangeAtMost(i32, -1, 1);
            const yt: i32 = y + random.intRangeAtMost(i32, -3, 1);
            const zt: i32 = z + random.intRangeAtMost(i32, -1, 1);

            if (level.get_tile(xt, yt, zt) == TileFile.dirt.get_id() and level.is_lit(xt, yt, zt)) {
                _ = level.set_tile(xt, yt, zt, TileFile.grass.get_id());
            }
        }

        _ = self;
    }
};
