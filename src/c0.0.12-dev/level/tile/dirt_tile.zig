const TileFile = @import("tile.zig");
const Tile = @import("tile.zig").Tile;
const AABB = @import("../../phys/aabb.zig").AABB;

pub const DirtTile = struct {
    tex: i32,
    id: i32,

    pub fn init(id: i32, tex: i32) DirtTile {
        const self = DirtTile{
            .tex = tex,
            .id = id,
        };

        return self;
    }

    pub fn _get_tex(self: *const DirtTile) i32 {
        return self.tex;
    }

    pub fn _get_id(self: *const DirtTile) i32 {
        return self.id;
    }

    pub fn get_texture(self: *const DirtTile) i32 {
        return self.tex;
    }

    pub fn get_aabb(self: *const DirtTile, x: i32, y: i32, z: i32) AABB {
        _ = self;
        return AABB{
            .x0 = @floatFromInt(x),
            .y0 = @floatFromInt(y),
            .z0 = @floatFromInt(z),
            .x1 = @floatFromInt(x + 1),
            .y1 = @floatFromInt(y + 1),
            .z1 = @floatFromInt(z + 1),
        };
    }

    pub fn _blocks_light(self: *const DirtTile) bool {
        _ = self;
        return true;
    }

    pub fn _is_solid(self: *const DirtTile) bool {
        _ = self;
        return true;
    }

    pub fn tick(self: *const DirtTile) void {
        _ = self;
    }
};
