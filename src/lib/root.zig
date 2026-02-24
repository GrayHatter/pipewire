const std = @import("std");

/// The translated pipewire headers.
pub const c = @import("c");

/// The wrapped standard calls that make it possible to link pipewire statically.
pub const wrap = @import("wrap");

pub const Logger = @import("Logger.zig");

pub fn init(argv: [:null]const ?[*:0]const u8) void {
    c.pw_init(@ptrCast(@constCast(&argv.len)), @ptrCast(@constCast(&argv.ptr)));
}

pub fn deinit() void {
    c.pw_deinit();
}

pub const MainLoop = struct {
    ptr: *c.pw_main_loop,

    pub fn run(ml: MainLoop) !void {
        if (c.pw_main_loop_run(ml.ptr) != 0) return error.MainLoopRunFailed;
    }

    pub fn init(props: ?*const c.struct_spa_dict) !MainLoop {
        if (c.pw_main_loop_new(props)) |loop| {
            return .{ .ptr = loop };
        } else return error.UnableToCreateLoop;
    }

    pub fn raze(ml: MainLoop) void {
        c.pw_main_loop_destroy(ml.ptr);
    }

    pub fn getLoop(ml: MainLoop) !Loop {
        return .{
            .ptr = c.pw_main_loop_get_loop(ml.ptr) orelse return error.UnableToGetLoop,
        };
    }
};

pub const Loop = struct {
    ptr: *c.pw_loop,
};

pub const Context = struct {
    ptr: *c.pw_context,

    pub fn init(loop: Loop) !Context {
        return .{
            .ptr = c.pw_context_new(loop.ptr, null, 0) orelse return error.UnableToCreateContext,
        };
    }

    pub fn connect(ctx: Context) !Core {
        return .{
            .ptr = c.pw_context_connect(ctx.ptr, null, 0) orelse return error.UnableToConnectCore,
        };
    }

    pub fn raze(ctx: Context) void {
        c.pw_context_destroy(ctx.ptr);
    }
};

pub const Core = struct {
    ptr: *c.pw_core,

    pub fn getRegistry(core: Core) !Registry {
        return .{
            .ptr = c.pw_core_get_registry(core.ptr, c.PW_VERSION_REGISTRY, 0) orelse return error.UnableToGetRegistry,
        };
    }

    pub fn raze(core: Core) void {
        _ = c.pw_core_disconnect(core.ptr);
    }
};

pub const Registry = struct {
    ptr: *c.pw_registry,

    pub fn ListenerFn(T: type) type {
        return *const fn (?*T, u32, u32, ?[:0]const u8, u32, ?*const c.spa_dict) void;
    }

    pub fn addListener(reg: Registry, T: type, comptime func: ListenerFn(T), reg_listener: *c.spa_hook, usrptr: ?*T) !void {
        const CFunc = struct {
            fn wrapper(
                ptr: ?*anyopaque,
                id: u32,
                permissions: u32,
                name: ?[*:0]const u8,
                version: u32,
                props: ?*const c.spa_dict,
            ) callconv(.c) void {
                @call(.auto, func, .{
                    @as(?*T, @ptrCast(@alignCast(ptr))), id, permissions, std.mem.span(name orelse ""), version, props,
                });
            }
        };

        if (c.pw_registry_add_listener(reg.ptr, reg_listener, &.{
            .version = c.PW_VERSION_REGISTRY_EVENTS,
            .global = &CFunc.wrapper,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }

    pub fn raze(reg: Registry) void {
        // This is what the Pipewire examples do
        _ = c.pw_proxy_destroy(@ptrCast(@alignCast(reg.ptr)));
    }
};

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

test {
    _ = &std.testing.refAllDecls(@This());
}
