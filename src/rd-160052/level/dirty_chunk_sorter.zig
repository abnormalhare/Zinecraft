const std = @import("std");

const Player = @import("../player.zig").Player;
const Frustum = @import("frustum.zig").Frustum;
const Chunk = @import("chunk.zig").Chunk;

pub const DirtyChunkSorter = struct {
    player: *Player,
    frustum: *Frustum,
    now: i64,

    pub fn new(io: std.Io, player: *Player, frustum: *Frustum) DirtyChunkSorter {
        return DirtyChunkSorter{
            .player = player,
            .frustum = frustum,
            .now = std.Io.Clock.now(.real, io).toMilliseconds(),
        };
    }

    pub fn compare(self: DirtyChunkSorter, c0: *Chunk, c1: *Chunk) bool {
        const b0 = self.frustum.is_visible(c0.aabb);
        const b1 = self.frustum.is_visible(c1.aabb);
        if (b0 and !b1) return true;
        if (b1 and !b0) return false;

        const t0: i32 = @intCast(@divTrunc(self.now - c0.dirtied_time, 2000));
        const t1: i32 = @intCast(@divTrunc(self.now - c1.dirtied_time, 2000));
        if (t0 < t1) return true;
        if (t0 > t1) return false;

        return c0.distance_to_sqr(self.player) < c1.distance_to_sqr(self.player);
    }
};
