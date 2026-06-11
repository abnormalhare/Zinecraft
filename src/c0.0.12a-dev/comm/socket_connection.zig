const std = @import("std");

const ConnectionListener = @import("connection_listener.zig").ConnectionListener;

pub const BUFFER_SIZE: i32 = 0x20000 - 4;

pub const SocketConnection = struct {
    connected: bool,

    stream: std.Io.net.Stream,

    read_buffer: [BUFFER_SIZE]u8,
    write_buffer: [BUFFER_SIZE]u8,

    last_read: i64,

    connection_listener: ConnectionListener,

    bytes_read: i32,
    total_bytes_written: i32,

    max_blocks_per_iteration: i32,

    pub fn new(io: std.Io, ip: []const u8, port: u16) !SocketConnection {
        const socket_channel = try std.Io.net.IpAddress.parseIp4(ip, port);
        const socket = try socket_channel.connect(io, .{});

        return SocketConnection{
            .connected = true,

            .stream = socket,

            .read_buffer = [_]u8{0} ** BUFFER_SIZE,
            .write_buffer = [_]u8{0} ** BUFFER_SIZE,

            .last_read = std.Io.Clock.now(.real, io).toMilliseconds(),

            .connection_listener = undefined,

            .bytes_read = 0,
            .total_bytes_written = 0,

            .max_blocks_per_iteration = 3,
        };
    }

    pub fn from_socket(io: std.Io, socket: std.Io.net.Stream) SocketConnection {
        return SocketConnection{
            .connected = true,

            .stream = socket,

            .read_buffer = [_]u8{0} ** BUFFER_SIZE,
            .write_buffer = [_]u8{0} ** BUFFER_SIZE,

            .last_read = std.Io.Clock.now(.real, io).toMilliseconds(),

            .connection_listener = undefined,

            .bytes_read = 0,
            .total_bytes_written = 0,

            .max_blocks_per_iteration = 3,
        };
    }

    pub fn get_ip(self: *SocketConnection) []u8 {
        return self.stream.socket.address.ip4.bytes;
    }

    pub fn get_buffer(self: *SocketConnection) []u8 {
        return &self.write_buffer;
    }

    pub fn set_connection_listener(self: *SocketConnection, connection_listener: ConnectionListener) void {
        self.connection_listener = connection_listener;
    }

    pub fn is_connected(self: *SocketConnection) bool {
        return self.connected;
    }

    pub fn disconnect(self: *SocketConnection, io: std.Io) void {
        self.connected = false;

        // skip in/out because they arent used and idk how to do it lol

        self.stream.close(io);
    }

    pub fn tick(self: *SocketConnection, io: std.Io) !void {
        var read_buf: [BUFFER_SIZE]u8 = undefined;
        var write_buf: [BUFFER_SIZE]u8 = undefined;

        var reader = self.stream.reader(io, &read_buf);
        var writer = self.stream.writer(io, &write_buf);

        reader.interface.readSliceAll(&self.read_buffer) catch |err| switch (err) {
            error.EndOfStream => {},
            else => unreachable,
        };
        try writer.interface.writeAll(&self.write_buffer);

        if (self.read_buffer.len > 0) {
            self.connection_listener.command(self.connection_listener.base, self.read_buffer[0], self.read_buffer.len, self.read_buffer[1..self.read_buffer.len]);
        }
    }

    pub fn get_sent_bytes(self: *SocketConnection) i32 {
        return self.total_bytes_written;
    }

    pub fn get_read_bytes(self: *SocketConnection) i32 {
        return self.bytes_read;
    }

    pub fn clear_sent_bytes(self: *SocketConnection) void {
        self.total_bytes_written = 0;
    }

    pub fn clear_read_bytes(self: *SocketConnection) void {
        self.bytes_read = 0;
    }
};
