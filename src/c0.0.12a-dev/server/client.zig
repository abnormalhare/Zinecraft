const std = @import("std");

const ConnectionListener = @import("../comm/connection_listener.zig").ConnectionListener;
const SocketConnection = @import("../comm/socket_connection.zig").SocketConnection;
const MinecraftServer = @import("minecraft_server.zig").MinecraftServer;

pub const Client = struct {
    connection_listener: ConnectionListener,

    server: *MinecraftServer,
    server_connection: *SocketConnection,

    pub fn new(alloc: std.mem.Allocator, server: *MinecraftServer, server_connection: *SocketConnection) !*Client {
        const self = try alloc.create(Client);

        self.* = Client{
            .connection_listener = undefined,
            .server = server,
            .server_connection = server_connection,
        };

        const connection_listener = ConnectionListener{
            .base = self,
            .command = @ptrCast(&Client.command),
            .handle_exception = @ptrCast(&Client.handle_exception),
        };
        self.connection_listener = connection_listener;

        self.server_connection.set_connection_listener(self.connection_listener);

        return self;
    }

    pub fn command(self: *const Client, cmd: u8, remaining: i32, in: []u8) void {
        _ = self;
        _ = cmd;
        _ = remaining;
        _ = in;
    }

    pub fn handle_exception(self: *const Client, e: anyerror) void {
        _ = self;
        std.debug.print("{any}", .{e});
    }

    pub fn disconnect(self: *Client) void {
        self.server.disconnect(self);
    }
};
