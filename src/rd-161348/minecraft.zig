const std = @import("std");
const Io = std.Io;
const glfw = @import("glfw");
const gl = @import("gl");
const stbi = @import("stbi");
const options = @import("options");

const Cube = @import("character/cube.zig").Cube;
const Zombie = @import("character/zombie.zig").Zombie;

const ChunkFile = @import("level/chunk.zig");
const Frustum = @import("level/frustum.zig").Frustum;
const TesselatorFile = @import("level/tesselator.zig");
const TileFile = @import("level/tile/tile.zig");
const Level = @import("level/level.zig").Level;
const LevelRenderer = @import("level/level_renderer.zig").LevelRenderer;

const ParticleEngine = @import("particle/particle_engine.zig").ParticleEngine;

const Player = @import("player.zig").Player;
const HitResult = @import("hit_result.zig").HitResult;
const Timer = @import("timer.zig").Timer;
const Textures = @import("textures.zig");

const FULLSCREEN_MODE: bool = options.fullscreen orelse false;

var width: i32 = undefined;
var height: i32 = undefined;

var fog_color0: [4]f32 = [_]f32{0} ** 4;
var fog_color1: [4]f32 = [_]f32{0} ** 4;

var timer: Timer = undefined;
var level: Level = undefined;
var level_renderer: *LevelRenderer = undefined;
var particle_engine: ParticleEngine = undefined;

var player: Player = undefined;
var zombies: std.ArrayList(Zombie) = .empty;
var zombie_alloc = std.heap.page_allocator;

var paint_texture: i32 = 1;

var viewport_buffer: [16]i32 = [_]i32{0} ** 16;
var select_buffer: [2000]u32 = [_]u32{0} ** 2000;

var hit_result: ?HitResult = null;

var window: *glfw.Window = undefined;
var cursor: *glfw.Cursor = undefined;

var running: bool = true;
var prng: std.Random.DefaultPrng = undefined;
var rand: std.Random = undefined;

var lb: [16]f32 = [_]f32{0} ** 16;

fn glfw_setup(w: i32, h: i32) !void {
    try glfw.init();
    errdefer {
        glfw.terminate();
        std.debug.print("Failed to initialize GLFW\n", .{});
        std.process.exit(1);
    }

    glfw.windowHint(.context_version_major, 1);
    glfw.windowHint(.context_version_minor, 1);

    var monitor: ?*glfw.Monitor = null;
    width = w;
    height = h;

    if (FULLSCREEN_MODE) {
        monitor = glfw.getPrimaryMonitor();
        const video_mode = try glfw.getVideoMode(monitor.?);
        width = video_mode.width;
        height = video_mode.height;
    }

    window = try .create(width, height, "RubyDung", monitor, null);

    glfw.makeContextCurrent(window);

    _ = glfw.setMouseButtonCallback(window, mouse_button_callback);
    _ = glfw.setKeyCallback(window, key_callback);
}

pub fn init(alloc: std.mem.Allocator, io: std.Io) !void {
    timer = Timer.new(io, 20.0);

    const col0: i32 = 0xFEFBFA;
    const col1: i32 = 0x0E0B0A;

    const fr: f32 = 0.5;
    const fg: f32 = 0.8;
    const fb: f32 = 1.0;

    fog_color0 = [_]f32{
        @as(f32, @floatFromInt((col0 >> 16) & 255)) / 255.0,
        @as(f32, @floatFromInt((col0 >> 8) & 255)) / 255.0,
        @as(f32, @floatFromInt((col0 >> 0) & 255)) / 255.0,
        1.0,
    };

    fog_color1 = [_]f32{
        @as(f32, @floatFromInt((col1 >> 16) & 255)) / 255.0,
        @as(f32, @floatFromInt((col1 >> 8) & 255)) / 255.0,
        @as(f32, @floatFromInt((col1 >> 0) & 255)) / 255.0,
        1.0,
    };

    prng = .init(@bitCast(std.Io.Clock.now(.real, io).toMilliseconds()));
    rand = prng.random();

    stbi.init(io, alloc);
    try glfw_setup(1024, 768);

    cursor = try .createStandard(.arrow);
    glfw.setCursor(window, cursor);

    try TesselatorFile.init(alloc);
    ChunkFile.init();

    gl.glEnable(gl.GL_TEXTURE_2D);
    gl.glShadeModel(gl.GL_SMOOTH);
    gl.glClearColor(fr, fg, fb, 0.0);

    gl.glClearDepth(1.0);
    gl.glEnable(gl.GL_DEPTH_TEST);
    gl.glDepthFunc(gl.GL_LEQUAL);

    gl.glEnable(gl.GL_ALPHA_TEST);
    gl.glAlphaFunc(gl.GL_GREATER, 0.5);

    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();

    gl.glMatrixMode(gl.GL_MODELVIEW);

    level = try .new(alloc, &rand, std.heap.page_allocator, 256, 256, 64);
    level_renderer = try LevelRenderer.new(alloc, io, &level);
    player = .new(&level, &rand);
    particle_engine = .new(alloc, &level);

    try glfw.setInputMode(window, .cursor, .disabled);
    glfw.getCursorPos(window, &last_x, &last_y);

    for (0..100) |_| {
        var zombie = Zombie.new(&level, &rand, 128.0, 0.0, 128.0);
        zombie.reset_pos(&rand);
        try zombies.append(zombie_alloc, zombie);
    }
}

pub fn destroy(alloc: std.mem.Allocator) void {
    level.save() catch {
        std.debug.print("OH NO! Could not save level!\n", .{});
    };

    zombies.deinit(zombie_alloc);

    level_renderer.deinit(alloc);
    alloc.destroy(level_renderer);

    level.deinit(alloc);

    TesselatorFile.deinit(alloc);

    stbi.deinit();
    cursor.destroy();
    window.destroy();
    glfw.terminate();
}

pub fn run(alloc: std.mem.Allocator, io: std.Io) !void {
    init(alloc, io) catch |err| {
        std.debug.print("Failed to start RubyDung\n{any}", .{err});
        std.process.exit(0);
    };
    defer destroy(alloc);

    const contained_alloc = std.heap.page_allocator;

    var last_time = std.Io.Clock.now(.real, io).toMilliseconds();
    var frames: i32 = 0;

    while (glfw.getKey(window, .escape) != .press and !window.shouldClose()) {
        timer.advance_time();

        for (0..@intCast(timer.ticks)) |_| {
            try tick();
        }

        try render(contained_alloc, io, timer.a);
        frames += 1;

        while (std.Io.Clock.now(.real, io).toMilliseconds() >= last_time + 1000) {
            std.debug.print("{} fps, {}\n", .{ frames, ChunkFile.updates });
            ChunkFile.updates = 0;
            last_time += 1000;
            frames = 0;
        }
    }
}

// read entity.move, alloc is contained
pub fn tick() !void {
    const alloc = std.heap.page_allocator;

    level.tick();
    try particle_engine.tick();

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
    level_renderer.pick(&player, Frustum.get_frustum());

    const hits: i32 = @intCast(gl.glRenderMode(gl.GL_RENDER));

    var closest: i64 = 0;
    var names: [10]i32 = [_]i32{0} ** 10;
    var hit_name_count: i32 = 0;

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
        hit_result = HitResult{ .htype = names[0], .x = names[1], .y = names[2], .z = names[3], .f = names[4] };
    } else {
        hit_result = null;
    }
}

fn mouse_button_callback(awindow: *glfw.Window, mouse_button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    if (mouse_button == .right and action == .press and hit_result != null) {
        const tile_id = level.get_tile(hit_result.?.x, hit_result.?.y, hit_result.?.z);
        const tile = TileFile.tiles[@intCast(tile_id)];
        const block_broke = level.set_tile(hit_result.?.x, hit_result.?.y, hit_result.?.z, 0);
        if (tile != null and block_broke) {
            tile.?.destroy(&level, &rand, hit_result.?.x, hit_result.?.y, hit_result.?.z, &particle_engine) catch |err| {
                std.debug.print("ERROR: tile failed to be destroyed: {any}", .{err});
            };
        }
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

        _ = level.set_tile(x, y, z, paint_texture);
    }
    _ = awindow;
    _ = mods;
}

fn key_callback(awindow: *glfw.Window, key: glfw.Key, scancode: i32, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
    if (action != .press) return;

    switch (key) {
        .enter => {
            level.save() catch {
                std.debug.print("OH NO! Could not save level!\n", .{});
            };
        },
        .one => {
            paint_texture = 1;
        },
        .two => {
            paint_texture = 3;
        },
        .three => {
            paint_texture = 4;
        },
        .four => {
            paint_texture = 5;
        },
        .six => {
            paint_texture = 6;
        },
        .g => {
            zombies.append(zombie_alloc, Zombie.new(&level, &rand, player.entity.x, player.entity.y, player.entity.z)) catch |err| {
                std.debug.print("ERROR: Failed to append zombie: {any}", .{err});
            };
        },
        else => {},
    }

    _ = awindow;
    _ = scancode;
    _ = mods;
}

var last_x: f64 = 0;
var last_y: f64 = 0;

pub fn render(alloc: std.mem.Allocator, io: std.Io, a: f32) !void {
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
    glfw.pollEvents();

    gl.glClear(gl.GL_DEPTH_BUFFER_BIT | gl.GL_COLOR_BUFFER_BIT);

    setup_camera(a);

    gl.glEnable(gl.GL_CULL_FACE);

    const frustum = Frustum.get_frustum();
    try level_renderer.update_dirty_chunks(alloc, &player);

    setup_fog(0);

    gl.glEnable(gl.GL_FOG);
    try level_renderer.render(&player, 0);

    for (zombies.items) |*zombie| {
        if (zombie.is_lit() and frustum.is_visible(zombie.entity.bb)) {
            try zombie.render(io, a);
        }
    }

    try particle_engine.render(&player, a, 0);

    setup_fog(1);
    try level_renderer.render(&player, 1);

    for (zombies.items) |*zombie| {
        if (!zombie.is_lit() and frustum.is_visible(zombie.entity.bb)) {
            try zombie.render(io, a);
        }
    }

    try particle_engine.render(&player, a, 1);

    gl.glDisable(gl.GL_LIGHTING);
    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glDisable(gl.GL_FOG);

    if (hit_result != null) {
        gl.glDisable(gl.GL_ALPHA_TEST);
        level_renderer.render_hit(hit_result.?);
        gl.glEnable(gl.GL_ALPHA_TEST);
    }

    try draw_gui(a);

    glfw.swapBuffers(window);
}

fn draw_gui(a: f32) !void {
    const screen_width = @divTrunc(width * 240, height);
    const screen_height = @divTrunc(height * 240, height);

    gl.glClear(gl.GL_DEPTH_BUFFER_BIT);

    gl.glMatrixMode(gl.GL_PROJECTION);
    gl.glLoadIdentity();
    gl.glOrtho(0.0, @floatFromInt(screen_width), @floatFromInt(screen_height), 0.0, 100.0, 300.0);

    gl.glMatrixMode(gl.GL_MODELVIEW);
    gl.glLoadIdentity();
    gl.glTranslatef(0.0, 0.0, -200.0);

    gl.glPushMatrix();
    gl.glTranslatef(@floatFromInt(screen_width - 16), 16.0, 0.0);

    var t = TesselatorFile.instance;

    gl.glScalef(16.0, 16.0, 16.0);
    gl.glRotatef(30.0, 1.0, 0.0, 0.0);
    gl.glRotatef(45.0, 0.0, 1.0, 0.0);
    gl.glTranslatef(-1.5, 0.5, -0.5);
    gl.glScalef(-1.0, -1.0, 1.0);

    const id = try Textures.load_texture("terrain.png", gl.GL_NEAREST);
    gl.glBindTexture(gl.GL_TEXTURE_2D, @intCast(id));
    gl.glEnable(gl.GL_TEXTURE_2D);

    t.init();
    TileFile.tiles[@intCast(paint_texture)].?.render(&t, &level, 0, -2, 0, 0);
    t.flush();

    gl.glDisable(gl.GL_TEXTURE_2D);
    gl.glPopMatrix();

    const wc = @divTrunc(screen_width, 2);
    const hc = @divTrunc(screen_height, 2);

    gl.glColor4f(1.0, 1.0, 1.0, 1.0);

    t.init();
    t.vertex(@floatFromInt(wc + 1), @floatFromInt(hc - 4), 0.0);
    t.vertex(@floatFromInt(wc - 0), @floatFromInt(hc - 4), 0.0);
    t.vertex(@floatFromInt(wc - 0), @floatFromInt(hc + 5), 0.0);
    t.vertex(@floatFromInt(wc + 1), @floatFromInt(hc + 5), 0.0);
    t.vertex(@floatFromInt(wc + 5), @floatFromInt(hc - 0), 0.0);
    t.vertex(@floatFromInt(wc - 4), @floatFromInt(hc - 0), 0.0);
    t.vertex(@floatFromInt(wc - 4), @floatFromInt(hc + 1), 0.0);
    t.vertex(@floatFromInt(wc + 5), @floatFromInt(hc + 1), 0.0);
    t.flush();

    _ = a;
}

fn setup_fog(i: i32) void {
    switch (i) {
        0 => {
            gl.glFogi(gl.GL_FOG_MODE, gl.GL_EXP);
            gl.glFogf(gl.GL_FOG_DENSITY, 0.001);
            gl.glFogfv(gl.GL_FOG_COLOR, &fog_color0);
            gl.glDisable(gl.GL_LIGHTING);
        },
        1 => {
            gl.glFogi(gl.GL_FOG_MODE, gl.GL_EXP);
            gl.glFogf(gl.GL_FOG_DENSITY, 0.06);
            gl.glFogfv(gl.GL_FOG_COLOR, &fog_color1);
            gl.glEnable(gl.GL_LIGHTING);
            gl.glEnable(gl.GL_COLOR_MATERIAL);

            const br: f32 = 0.6;
            gl.glLightModelfv(gl.GL_LIGHT_MODEL_AMBIENT, get_buffer(br, br, br, 1.0));
        },
        else => {},
    }
}

fn get_buffer(a: f32, b: f32, c: f32, d: f32) [*c]const f32 {
    lb[0] = a;
    lb[1] = b;
    lb[2] = c;
    lb[3] = d;
    return &lb;
}
