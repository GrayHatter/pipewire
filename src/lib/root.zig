const std = @import("std");

/// The translated pipewire headers.
pub const c = @import("c");

/// The wrapped standard calls that make it possible to link pipewire statically.
pub const wrap = @import("wrap");

pub const Logger = @import("Logger.zig");

pub const Direction = enum(c_uint) { input = c.PW_DIRECTION_INPUT, output = c.PW_DIRECTION_OUTPUT };

pub const Stream = struct {
    pub const Flags = packed struct(c_int) {
        AUTOCONNECT: bool = false,
        INACTIVE: bool = false,
        MAP_BUFFERS: bool = false,
        DRIVER: bool = false,
        RT_PROCESS: bool = false,
        NO_CONVERT: bool = false,
        EXCLUSIVE: bool = false,
        DONT_RECONNECT: bool = false,
        ALLOC_BUFFERS: bool = false,
        TRIGGER: bool = false,
        ASYNC: bool = false,
        EARLY_PROCESS: bool = false,
        RT_TRIGGER_DONE: bool = false,
        _: u19 = 0,

        pub const NONE: Flags = .{};
    };

    pub fn connect(
        stream: ?*c.struct_pw_stream,
        direction: Direction,
        target_id: u32,
        flags: Flags,
        params: []const *const c.struct_spa_pod,
    ) !void {
        if (c.pw_stream_connect(
            stream,
            @intFromEnum(direction),
            target_id,
            @bitCast(flags),
            @ptrCast(@constCast(params.ptr)),
            @truncate(params.len),
        ) != 0) return error.Unspecified;
    }
};

comptime {
    // Reference all decls since they include exports.
    for (std.meta.declarations(@This())) |decl| {
        _ = &@field(@This(), decl.name);
    }
    _ = &Logger;
}
