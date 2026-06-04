const std = @import("std");
const gl = @import("gl");
const stbi = @import("stbi");

var id_map: std.StringHashMap(i32) = .init(std.heap.page_allocator);
var last_id: i32 = -9999999;

pub fn load_texture(resource_name: [:0]const u8, mode: i32) !i32 {
    if (id_map.contains(resource_name)) {
        return id_map.get(resource_name).?;
    }

    var e: i32 = undefined;
    gl.glGenTextures(1, @ptrCast(&e));

    bind(e);

    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, mode);
    gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, mode);

    var img = try stbi.Image.loadFromFile(resource_name, 4);
    defer img.deinit();

    const w: i32 = @intCast(img.width);
    const h: i32 = @intCast(img.height);

    _ = gl.gluBuild2DMipmaps(gl.GL_TEXTURE_2D, gl.GL_RGBA, w, h, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, img.data.ptr);

    return e;
}

fn bind(id: i32) void {
    std.debug.print("{}\n", .{id});
    if (id != last_id) {
        gl.glBindTexture(gl.GL_TEXTURE_2D, @bitCast(id));
        last_id = id;
    }
}
