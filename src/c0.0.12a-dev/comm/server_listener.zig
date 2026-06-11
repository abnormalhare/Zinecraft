const SocketConnection = @import("socket_connection.zig").SocketConnection;

pub const ServerListener = struct {
    base: *const anyopaque,

    client_connected: *const fn (*const anyopaque, server_connection: *SocketConnection) void,
    client_exception: *const fn (*const anyopaque, server_connection: *SocketConnection, e: anyerror) void,
};
