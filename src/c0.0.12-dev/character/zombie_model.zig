const std = @import("std");

const Cube = @import("cube.zig").Cube;

pub const ZombieModel = struct {
    head: Cube,
    body: Cube,
    arm0: Cube,
    arm1: Cube,
    leg0: Cube,
    leg1: Cube,

    pub fn new() ZombieModel {
        var head = Cube.new(0, 0);
        head.add_box(-4.0, -8.0, -4.0, 8, 8, 8);

        var body = Cube.new(16, 16);
        body.add_box(-4.0, 0.0, -2.0, 8, 12, 4);

        var arm0 = Cube.new(40, 16);
        arm0.add_box(-3.0, -2.0, -2.0, 4, 12, 4);
        arm0.set_pos(-5.0, 2.0, 0.0);

        var arm1 = Cube.new(40, 16);
        arm1.add_box(-1.0, -2.0, -2.0, 4, 12, 4);
        arm1.set_pos(5.0, 2.0, 0.0);

        var leg0 = Cube.new(0, 16);
        leg0.add_box(-2.0, 0.0, -2.0, 4, 12, 4);
        leg0.set_pos(-2.0, 12.0, 0.0);

        var leg1 = Cube.new(0, 16);
        leg1.add_box(-2.0, 0.0, -2.0, 4, 12, 4);
        leg1.set_pos(2.0, 12.0, 0.0);

        return ZombieModel{
            .head = head,
            .body = body,
            .arm0 = arm0,
            .arm1 = arm1,
            .leg0 = leg0,
            .leg1 = leg1,
        };
    }

    pub fn render(self: *ZombieModel, time: f64) void {
        self.head.y_rot = @as(f32, @floatCast(@sin(time * 0.83)));
        self.head.x_rot = @as(f32, @floatCast(@sin(time))) * 0.8;

        self.arm0.x_rot = @as(f32, @floatCast(@sin(time * 0.6662 + std.math.pi))) * 2.0;
        self.arm0.z_rot = @as(f32, @floatCast(@sin(time * 0.2312) + 1.0));

        self.arm1.x_rot = @as(f32, @floatCast(@sin(time * 0.6662))) * 2.0;
        self.arm1.z_rot = @as(f32, @floatCast(@sin(time * 0.2812) - 1.0));

        self.leg0.x_rot = @as(f32, @floatCast(@sin(time * 0.6662))) * 1.4;
        self.leg1.x_rot = @as(f32, @floatCast(@sin(time * 0.6662 + std.math.pi))) * 1.4;

        self.head.render();
        self.body.render();
        self.arm0.render();
        self.arm1.render();
        self.leg0.render();
        self.leg1.render();
    }
};
