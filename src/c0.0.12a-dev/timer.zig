const std = @import("std");

const NS_PER_SECOND = std.time.ns_per_s;
const MAX_NS_PER_UPDATE: f32 = NS_PER_SECOND;
const MAX_TICKS_PER_UPDATE = 100;

pub const Timer = struct {
    ticks_per_second: f32,
    last_time: i96,
    ticks: i32,
    a: f32,
    time_scale: f32,
    fps: f32,
    passed_time: f32,

    io: std.Io,

    pub fn new(io: std.Io, ticks_per_second: f32) Timer {
        return Timer{
            .ticks_per_second = ticks_per_second,
            .last_time = std.Io.Clock.now(.real, io).nanoseconds,
            .ticks = 0,
            .a = 0.0,
            .time_scale = 1.0,
            .fps = 0.0,
            .passed_time = 0.0,

            .io = io,
        };
    }

    pub fn advance_time(self: *Timer) void {
        const now = std.Io.Clock.now(.real, self.io).nanoseconds;
        var passed_ns = now - self.last_time;
        self.last_time = now;

        if (passed_ns < 0.0) {
            passed_ns = 0.0;
        }

        if (passed_ns > MAX_NS_PER_UPDATE) {
            passed_ns = MAX_NS_PER_UPDATE;
        }

        self.fps = @floatFromInt(@divTrunc(NS_PER_SECOND, passed_ns));
        self.passed_time += @as(f32, @floatFromInt(passed_ns)) * self.time_scale * self.ticks_per_second / @as(f32, @floatFromInt(NS_PER_SECOND));

        self.ticks = @intFromFloat(self.passed_time);
        if (self.ticks > MAX_TICKS_PER_UPDATE) {
            self.ticks = MAX_TICKS_PER_UPDATE;
        }

        self.passed_time -= @floatFromInt(self.ticks);
        self.a = self.passed_time;
    }
};
