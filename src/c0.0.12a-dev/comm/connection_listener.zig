pub const ConnectionListener = struct {
    base: *const anyopaque,

    handle_exception: *const fn (*const anyopaque, e: anyerror) void,
    command: *const fn (*const anyopaque, cmd: u8, remaining: i32, in: []u8) void,
};
