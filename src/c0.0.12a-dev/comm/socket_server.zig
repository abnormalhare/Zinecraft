const std = @import("std");

const ServerListener = @import("server_listener.zig").ServerListener;
const SocketConnection = @import("socket_connection.zig").SocketConnection;

pub const SocketServer = struct {
    group: std.Io.Group,
    mutex: std.Io.Mutex,

    ssc: std.Io.net.Server,
    server_listener: ServerListener,
    connections: std.ArrayList(SocketConnection),
    alloc: std.mem.Allocator,

    pub fn new(io: std.Io, alloc: std.mem.Allocator, ip: []const u8, port: u16, server_listener: ServerListener) !*SocketServer {
        var self = try alloc.create(SocketServer);

        const hostip = try std.Io.net.IpAddress.parseIp4(ip, port);

        self.* = SocketServer{
            .group = .init,
            .mutex = .init,

            .ssc = try hostip.listen(io, .{}),
            .server_listener = server_listener,
            .connections = .empty,
            .alloc = alloc,
        };

        self.group.async(io, SocketServer.accept_loop, .{ self, io });
        self.group.async(io, SocketServer.game_tick, .{ self, io });

        return self;
    }

    pub fn deinit(self: *SocketServer, io: std.Io) void {
        for (self.connections.items) |*socket_connection| {
            socket_connection.disconnect(io);
        }

        self.connections.deinit(self.alloc);

        self.group.cancel(io);
    }

    fn remove_socket_connect(self: *SocketServer, socket_connection: *SocketConnection) void {
        for (self.connections.items, 0..) |*connection, idx| {
            if (socket_connection == connection) {
                _ = self.connections.swapRemove(idx);
                break;
            }
        }
    }

    pub fn accept_loop(self: *SocketServer, io: std.Io) void {
        while (true) {
            const socket_channel = self.ssc.accept(io) catch continue;

            var buffer: [32]u8 = undefined;
            var writer: std.Io.Writer = .fixed(&buffer);
            socket_channel.socket.address.ip4.format(&writer) catch {
                socket_channel.close(io);
                continue;
            };

            std.log.info("{s} connected", .{writer.buffered()});
            writer.flush() catch {};

            var i = SocketConnection.from_socket(io, socket_channel);

            self.mutex.lock(io) catch {
                socket_channel.close(io);
                continue;
            };
            self.connections.append(self.alloc, i) catch {
                self.mutex.unlock(io);
                socket_channel.close(io);
                continue;
            };
            self.mutex.unlock(io);

            self.server_listener.client_connected(self.server_listener.base, &i);
        }
    }

    pub fn game_tick(self: *SocketServer, io: std.Io) void {
        while (true) {
            var to_remove: std.ArrayList(*SocketConnection) = .empty;
            for (self.connections.items) |*socket_connection| {
                if (!socket_connection.is_connected()) {
                    socket_connection.disconnect(io);
                    to_remove.append(self.alloc, socket_connection) catch {
                        continue;
                    };
                } else {
                    socket_connection.tick(io) catch |err| {
                        socket_connection.disconnect(io);
                        self.server_listener.client_exception(self.server_listener.base, socket_connection, err);
                    };
                }
            }

            self.mutex.lock(io) catch {
                continue;
            };
            for (to_remove.items) |connection| {
                self.remove_socket_connect(connection);
            }
            self.mutex.unlock(io);
        }
    }

    pub fn tick(self: *SocketServer, io: std.Io) void {
        self.group.await(io) catch {
            self.deinit(io);
        };
    }
};
