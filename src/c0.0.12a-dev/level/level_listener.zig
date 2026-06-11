pub fn LevelListener(comptime base: type) type {
    return struct {
        base: base,

        tile_changed: *const fn (base, i32, i32, i32) void,
        light_column_changed: *const fn (base, i32, i32, i32, i32) void,
        all_changed: *const fn (base) void,
    };
}
