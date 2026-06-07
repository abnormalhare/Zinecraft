const std = @import("std");
const Io = std.Io;
const glfw = @import("glfw");
const gl = @import("gl");
const stbi = @import("stbi");

const Cube = @import("character/cube.zig").Cube;
const Zombie = @import("character/zombie.zig").Zombie;

const ChunkFile = @import("level/chunk.zig");
const Level = @import("level/level.zig").Level;
const LevelRenderer = @import("level/level_renderer.zig").LevelRenderer;

const Player = @import("player.zig").Player;
const HitResult = @import("hit_result.zig").HitResult;
const Timer = @import("timer.zig").Timer;
const Textures = @import("textures.zig");

const FULLSCREEN_MODE: bool = false;

var width: i32 = undefined;
var height: i32 = undefined;
var fog_color: [4]f32 = [_]f32{0} ** 4;

var timer: Timer = undefined;
var level: Level = undefined;
var level_renderer: *LevelRenderer = undefined;
var player: Player = undefined;
var zombies: std.ArrayList(Zombie) = .empty;

var viewport_buffer: [16]i32 = [_]i32{0} ** 16;
var select_buffer: [2000]u32 = [_]u32{0} ** 2000;

var hit_result: ?HitResult = null;

var window: *glfw.Window = undefined;
var cursor: *glfw.Cursor = undefined;

var running: bool = true;
var prng: std.Random.DefaultPrng = undefined;
var rand: std.Random = undefined;

fn glfw_setup(w: i32, h: i32) !void {
    try glfw.init();
    errdefer {
        glfw.terminate();
        std.debug.print("Failed to initialize GLFW\n", .{});
        std.process.exit(1);
    }

    glfw.windowHint(.context_version_major, 1);
    glfw.windowHint(.context_version_minor, 1);

    window = try .create(w, h, "RubyDung", null, null);

    glfw.makeContextCurrent(window);

    _ = glfw.setMouseButtonCallback(window, mouse_button_callback);
    _ = glfw.setKeyCallback(window, key_callback);

    width = w;
    height = h;
}

pub fn init(alloc: std.mem.Allocator, io: std.Io) !void {
    timer = Timer.new(io, 60.0);

    const col: i32 = 0x0E0B0A;

    const fr: f32 = 0.5;
    const fg: f32 = 0.8;
    const fb: f32 = 1.0;

    fog_color = [_]f32{
        @as(f32, @floatFromInt((col >> 16) & 255)) / 255.0,
        @as(f32, @floatFromInt((col >> 8) & 255)) / 255.0,
        @as(f32, @floatFromInt((col >> 0) & 255)) / 255.0,
        1.0,
    };

    prng = .init(@bitCast(std.Io.Clock.now(.real, io).toMilliseconds()));
    rand = prng.random();

    stbi.init(io, alloc);
    try glfw_setup(1024, 768);
    cursor = try .createStandard(.arrow);
    glfw.setCursor(window, cursor);

    try ChunkFile.init(alloc);

    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glShadeModel(gl.GL_SMOOTH);
    gl.glClearColor(fr, fg, fb, 0.0);
    gl.glClearDepth(1.0);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();
    gl.glMatrixMode(gl.GL_MODELVIEW);

    level = try .new(alloc, std.heap.page_allocator, 256, 256, 64);
    level_renderer = try LevelRenderer.new(alloc, &level);
    player = .new(&level, &rand);

    try glfw.setInputMode(window, .cursor, .disabled);
    glfw.getCursorPos(window, &last_x, &last_y);

    for (0..100) |_| {
        try zombies.append(alloc, Zombie.new(&level, &rand, 128.0, 0.0, 128.0));
    }
}

pub fn destroy(alloc: std.mem.Allocator) void {
    level.save() catch {
        std.debug.print("OH NO! Could not save level!\n", .{});
    };

    zombies.deinit(alloc);

    level_renderer.deinit(alloc);
    alloc.destroy(level_renderer);

    level.deinit(alloc);

    ChunkFile.deinit(alloc);

    stbi.deinit();
    cursor.destroy();
    window.destroy();
    glfw.terminate();
}

pub fn run(alloc: std.mem.Allocator, io: std.Io) !void {
    init(alloc, io) catch {
        std.debug.print("Failed to start RubyDung\n", .{});
        std.process.exit(0);
    };
    defer destroy(alloc);

    var last_time = std.Io.Clock.now(.real, io).toMilliseconds();
    var frames: i32 = 0;

    while (glfw.getKey(window, .escape) != .press and !window.shouldClose()) {
        timer.advance_time();

        for (0..@intCast(timer.ticks)) |_| {
            try tick();
        }

        try render(io, timer.a);
        frames += 1;

        while (std.Io.Clock.now(.real, io).toMilliseconds() >= last_time + 1000) {
            std.debug.print("{} fps, {}\n", .{ frames, ChunkFile.updates });
            ChunkFile.updates = 0;
            last_time += 1000;
            frames = 0;
        }
    }
}

pub fn tick() !void {
    const alloc = std.heap.page_allocator;

    for (zombies.items) |*zombie| {
        try zombie.tick(alloc, &rand);
    }
    try player.tick(window, alloc, &rand);
}

fn move_camera_to_player(a: f32) void {
    const entity = player.entity;

    gl.glTranslatef(0.0, 0.0, -0.3);
    gl.glRotatef(entity.x_rot, 1.0, 0.0, 0.0);
    gl.glRotatef(entity.y_rot, 0.0, 1.0, 0.0);

    const x: f32 = entity.xo + (entity.x - entity.xo) * a;
    const y: f32 = entity.yo + (entity.y - entity.yo) * a;
    const z: f32 = entity.zo + (entity.z - entity.zo) * a;
    gl.glTranslatef(-x, -y, -z);
}

fn setup_camera(a: f32) void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    const fwidth: f32 = @floatFromInt(width);
    const fheight: f32 = @floatFromInt(height);
    gl.gluPerspective(70.0, fwidth / fheight, 0.05, 1000.0);

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    move_camera_to_player(a);
}

fn setup_pick_camera(a: f32, x: i32, y: i32) void {
    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();
    gl.glGetIntegerv(gl.GL_VIEWPORT, &viewport_buffer);
    gl.gluPickMatrix(@floatFromInt(x), @floatFromInt(y), 5.0, 5.0, &viewport_buffer);

    const fwidth: f32 = @floatFromInt(width);
    const fheight: f32 = @floatFromInt(height);
    gl.gluPerspective(70.0, fwidth / fheight, 0.05, 1000.0);

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();

    move_camera_to_player(a);
}

fn pick(a: f32) void {
    gl.glSelectBuffer(2000, &select_buffer);
    _ = gl.glRenderMode(gl.GL_SELECT);

    setup_pick_camera(a, @divTrunc(width, 2), @divTrunc(height, 2));
    level_renderer.pick(&player);

    const hits: i32 = @intCast(gl.glRenderMode(gl.GL_RENDER));

    var closest: i64 = 0;
    var names: [10]i32 = [_]i32{0} ** 10;
    var hit_name_count: i32 = 0;

    // std.debug.print("hits: {}\n", .{hits});

    var idx: usize = 0;
    for (0..@intCast(hits)) |i| {
        const name_count = select_buffer[idx];
        idx += 1;

        const min_z: i64 = @intCast(select_buffer[idx]);
        idx += 1;

        idx += 1;

        if (min_z >= closest and i != 0) {
            idx += name_count;
            continue;
        }

        closest = min_z;
        hit_name_count = @bitCast(name_count);

        for (0..@intCast(name_count)) |j| {
            names[j] = @bitCast(select_buffer[idx]);
            idx += 1;
        }
    }

    if (hit_name_count > 0) {
        hit_result = HitResult{ .x = names[0], .y = names[1], .z = names[2], .o = names[3], .f = names[4] };
    } else {
        hit_result = null;
    }
}

fn mouse_button_callback(awindow: *glfw.Window, mouse_button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    if (mouse_button == .right and action == .press and hit_result != null) {
        level.set_tile(hit_result.?.x, hit_result.?.y, hit_result.?.z, 0);
    }

    if (mouse_button == .left and action == .press and hit_result != null) {
        var x: i32 = hit_result.?.x;
        var y: i32 = hit_result.?.y;
        var z: i32 = hit_result.?.z;

        switch (hit_result.?.f) {
            0 => y -= 1,
            1 => y += 1,
            2 => z -= 1,
            3 => z += 1,
            4 => x -= 1,
            5 => x += 1,
            else => {},
        }

        level.set_tile(x, y, z, 1);
    }
    _ = awindow;
    _ = mods;
}

fn key_callback(awindow: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    if (key == .enter and action == .press) {
        level.save() catch {
            std.debug.print("OH NO! Could not save level!\n", .{});
        };
    }

    _ = awindow;
    _ = scancode;
    _ = mods;
}

var last_x: f64 = 0;
var last_y: f64 = 0;

pub fn render(io: std.Io, a: f32) !void {
    var x: f64 = undefined;
    var y: f64 = undefined;
    glfw.getCursorPos(window, &x, &y);

    const xo: f32 = @floatCast(x - last_x);
    const yo: f32 = @floatCast(y - last_y);

    player.turn(xo, yo);

    last_x = x;
    last_y = y;
    pick(a);

    // mouse and keyboard handled with callbacks

    gl.glClear(gl.GL_DEPTH_BUFFER_BIT | gl.GL_COLOR_BUFFER_BIT);

    setup_camera(a);

    gl.glEnable(gl.GL_CULL_FACE);

    gl.glEnable(gl.GL_FOG);
    gl.glFogi(gl.GL_FOG_MODE, gl.GL_EXP);
    gl.glFogf(gl.GL_FOG_DENSITY, 0.2);
    gl.glFogfv(gl.GL_FOG_COLOR, &fog_color);
    gl.glDisable(gl.GL_FOG);

    try level_renderer.render(&player, 0);

    for (zombies.items) |*zombie| {
        try zombie.render(io, a);
    }

    gl.glEnable(gl.GL_FOG);
    try level_renderer.render(&player, 1);

    gl.glDisable(gl.GL_TEXTURE_2D);
    if (hit_result != null) {
        level_renderer.render_hit(io, hit_result.?);
    }

    _ = Cube.new(0, 0);

    gl.glDisable(gl.GL_FOG);
    glfw.pollEvents();
    glfw.swapBuffers(window);
}
