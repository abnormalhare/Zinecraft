const TileFile = @import("tile.zig");
const Tile = @import("tile.zig").Tile;

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
