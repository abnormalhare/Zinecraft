const std = @import("std");

const ServerListener = @import("../comm/server_listener.zig").ServerListener;
const SocketConnection = @import("../comm/socket_connection.zig").SocketConnection;
const SocketServer = @import("../comm/socket_server.zig").SocketServer;
const Client = @import("client.zig").Client;

pub const MinecraftServer = struct {
    server_listener: ServerListener,
    socket_server: *SocketServer,

    client_map: std.AutoHashMap(*SocketConnection, *Client),
    clients: std.ArrayList(*Client),

    alloc: std.mem.Allocator,

    pub fn new(io: std.Io, create_alloc: std.mem.Allocator, alloc: std.mem.Allocator, ip: []const u8, port: u16) !*MinecraftServer {
        const self = try create_alloc.create(MinecraftServer);

        self.* = MinecraftServer{
            .server_listener = undefined,
            .socket_server = undefined,

            .client_map = .init(alloc),
            .clients = .empty,

            .alloc = alloc,
        };

        self.server_listener = ServerListener{
            .base = self,
            .client_connected = @ptrCast(&MinecraftServer.client_connected),
            .client_exception = @ptrCast(&MinecraftServer.client_exception),
        };
        self.socket_server = try SocketServer.new(io, alloc, ip, port, self.server_listener);

        return self;
    }

    pub fn deinit(self: *MinecraftServer) void {
        self.alloc.destroy(self.socket_server);

        self.client_map.deinit();
        for (self.clients.items) |*client| {
            self.alloc.destroy(client);
        }
        self.clients.deinit(self.alloc);
    }

    pub fn client_connected(self: *MinecraftServer, server_connection: *SocketConnection) void {
        const client = Client.new(self.alloc, self, server_connection) catch {
            std.debug.print("OH NO! We ran out of memory!\n", .{});
            return;
        };
        self.client_map.put(server_connection, client) catch {
            std.debug.print("OH NO! We ran out of memory!\n", .{});
            return;
        };
        self.clients.append(self.alloc, client) catch {
            std.debug.print("OH NO! We ran out of memory! 2!\n", .{});
            return;
        };
    }

    pub fn disconnect(self: *MinecraftServer, client: *Client) void {
        self.client_map.remove(client.server_connection);

        for (self.clients.items, 0..) |c, idx| {
            if (c == client) {
                self.clients.swapRemove(idx);
                self.alloc.destroy(c);
                break;
            }
        }
    }

    pub fn client_exception(self: *MinecraftServer, server_connection: *SocketConnection, e: anyerror) void {
        const client = self.client_map.get(server_connection).?;
        client.handle_exception(e);
    }

    pub fn run(self: *MinecraftServer, io: std.Io) void {
        while (true) {
            self.tick(io);
        }
    }

    fn tick(self: *MinecraftServer, io: std.Io) void {
        self.socket_server.tick(io);
    }
};
