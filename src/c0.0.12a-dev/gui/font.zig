const std = @import("std");
const gl = @import("gl");
const stbi = @import("stbi");

const Textures = @import("../render/textures.zig").Textures;
const TesselatorFile = @import("../render/tesselator.zig");

pub const Font = struct {
    char_widths: [256]i32,
    font_texture: i32,

    pub fn new(name: [:0]const u8, textures: *Textures) !Font {
        var img = try stbi.Image.loadFromFile(name, 4);
        defer img.deinit();

        const w: i32 = @intCast(img.width);

        var char_widths = [_]i32{0} ** 256;

        for (0..128) |i| {
            const xt = i % 16;
            const yt = @divTrunc(i, 16);

            var x: i32 = 0;
            var empty_column: bool = false;
            while (x < 8 and !empty_column) : (x += 1) {
                const x_pixel: i32 = @as(i32, @intCast(xt)) * 8 + x;

                empty_column = true;

                var y: i32 = 0;
                while (y < 8 and empty_column) : (y += 1) {
                    const y_pixel = (@as(i32, @intCast(yt)) * 8 + y) * w;
                    const pixel = img.data[@intCast((x_pixel + y_pixel) * 4 + 2)]; // check B of RGBA (why?)
                    if (pixel > 128) {
                        empty_column = false;
                    }
                }
            }

            if (i == 32) {
                x = 4;
            }
            char_widths[i] = x;
        }

        return Font{
            .char_widths = char_widths,
            .font_texture = try textures.load_texture(name, gl.GL_NEAREST),
        };
    }

    pub fn draw_shadow(self: *Font, str: []const u8, x: i32, y: i32, color: i32) void {
        self.draw(str, x + 1, y + 1, color, true);
        self.draw(str, x, y, color, false);
    }

    pub fn draw(self: *Font, str: []const u8, x: i32, y: i32, color: i32, darken: bool) void {
        var real_color: i32 = color;
        if (darken) {
            real_color = (color & 0xFCFCFC) >> 2;
        }

        gl.glEnable(gl.GL_TEXTURE_2D);
        gl.glBindTexture(gl.GL_TEXTURE_2D, @bitCast(self.font_texture));

        var t = &TesselatorFile.instance;
        t.init();
        t.colori(real_color);

        var xo: i32 = 0;

        var i: usize = 0;
        while (i < str.len) : (i += 1) {
            if (str[i] == 38) {
                const maybe_ix = std.mem.find(u8, "0123456789abcdef", &.{str[i + 1]});
                if (maybe_ix) |uix| {
                    const ix: i32 = @intCast(uix);
                    const iy = (ix & 8) * 8;

                    const b = ((ix & 1) >> 0) * 191 + iy;
                    const g = ((ix & 2) >> 1) * 191 + iy;
                    const r = ((ix & 4) >> 2) * 191 + iy;

                    var font_color = (r << 16) | (g << 8) | b;
                    if (darken) {
                        font_color = (font_color & 0xFCFCFC) >> 2;
                    }

                    t.colori(font_color);
                    i += 2;
                }
            }

            const ix: i32 = str[i] % 16 * 8;
            const iy: i32 = @divTrunc(str[i], 16) * 8;

            const fx: f32 = @floatFromInt(ix);
            const fy: f32 = @floatFromInt(iy);
            const fw: f32 = @floatFromInt(ix + 8);
            const fh: f32 = @floatFromInt(iy + 8);

            t.vertex_uv(@floatFromInt(x + xo + 0), @floatFromInt(y + 8), 0.0, fx / 128.0, fh / 128.0);
            t.vertex_uv(@floatFromInt(x + xo + 8), @floatFromInt(y + 8), 0.0, fw / 128.0, fh / 128.0);
            t.vertex_uv(@floatFromInt(x + xo + 8), @floatFromInt(y + 0), 0.0, fw / 128.0, fy / 128.0);
            t.vertex_uv(@floatFromInt(x + xo + 0), @floatFromInt(y + 0), 0.0, fx / 128.0, fy / 128.0);

            xo += self.char_widths[str[i]];
        }

        t.flush();
        gl.glDisable(gl.GL_TEXTURE_2D);
    }

    pub fn width(self: *Font, str: []const u8) i32 {
        var len: i32 = 0;

        for (0..str.len) |i| {
            if (str[i] == 38) {
                i += 1;
            } else {
                len += self.char_widths[str[i]];
            }
        }

        return len;
    }
};
