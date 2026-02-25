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
        return *const fn (?*T, Id, u32, ?[:0]const u8, u32, ?*const c.spa_dict) void;
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
                    @as(?*T, @ptrCast(@alignCast(ptr))), @as(Id, @enumFromInt(id)), permissions, std.mem.span(name orelse ""), version, props,
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

pub const Properties = struct {
    ptr: *c.pw_properties,
    pub fn init(comptime kv: []const [*:0]const u8) !Properties {
        //const len = comptime std.mem.span(key_values).len;
        comptime std.debug.assert(kv.len & 1 == 0);
        //const Args = @Tuple([kv.len:null]?[*:0]const u8;
        var args: @Tuple(&@as([7]type, @splat(?[*:0]const u8))) = undefined;
        inline for (kv, 0..) |src, i| {
            args[i] = src;
            std.debug.print("{*} {s}\n", .{ src, std.mem.span(src) });
        } else args[kv.len] = null;
        const props: ?*c.pw_properties = @call(.auto, c.pw_properties_new, args);
        return .{ .ptr = props orelse return error.UnableToCReateProperties };
    }
};

pub const SimplePlugin = struct {
    pub const Dict = extern struct {
        flags: u32,
        count: u32,
        items: [*]Item,

        pub const Item = extern struct {
            key: [*]const u8,
            value: [*]const u8,
        };
    };

    pub const POD = PlainOldData;
    pub const PlainOldData = struct {
        pub const Builder = struct {};
    };
};

pub const Direction = enum(c_uint) { input = c.PW_DIRECTION_INPUT, output = c.PW_DIRECTION_OUTPUT };

pub const Id = enum(u32) { core = 0, client = 1, any = std.math.maxInt(u32), _ };

pub const Stream = struct {
    ptr: *c.pw_stream,

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

    pub const State = enum(u32) {
        _,
    };

    pub fn Events(T: type) type {
        return struct {
            version: u32 = c.PW_VERSION_STREAM_EVENTS,
            destroy: ?*const fn (?*T) void = null,
            state_changed: ?*const fn (?*T, State, State, ?[*:0]const u8) void = null, // old, new, err
            control_info: ?*const fn (?*T, u32, *const c.pw_stream_control) void = null, // )(void *data, uint32_t id, const struct pw_stream_control *control)
            io_changed: ?*const fn (?*T, u32, *anyopaque, u32) void = null, // )(void *data, uint32_t id, void *area, uint32_t size)
            param_changed: ?*const fn (?*T, Id, *const c.spa_pod) void = null, // )(void *data, uint32_t id, const struct spa_pod *param)
            add_buffer: ?*const fn (?*T, *c.pw_buffer) void = null, // )(void *data, struct pw_buffer *buffer)
            remove_buffer: ?*const fn (?*T, *c.pw_buffer) void = null, // )(void *data, struct pw_buffer *buffer)
            process: ?*const fn (?*T) void = null,
            drained: ?*const fn (?*T) void = null,
            command: ?*const fn (?*T, *const c.spa_command) void = null, // )(void *data, const struct spa_command *command)
            trigger_done: ?*const fn (?*T) void = null, // )(void *data)
        };
    }

    pub fn simple(T: type, loop: Loop, name: [:0]const u8, props: Properties, comptime events: Events(T), usrptr: ?*T) !Stream {
        const CFunc = struct {
            fn process(ptr: ?*anyopaque) callconv(.c) void {
                if (comptime events.process) |proc|
                    @call(.auto, proc, .{@as(?*T, @ptrCast(@alignCast(ptr)))});
            }
        };

        return .{
            .ptr = c.pw_stream_new_simple(loop.ptr, name.ptr, props.ptr, &.{
                .version = events.version,
                .process = &CFunc.process,
            }, usrptr) orelse return error.UnableToAddSimpleStream,
        };
    }

    pub fn raze(stream: Stream) void {
        c.pw_stream_destroy(stream.ptr);
    }

    pub fn connect(
        stream: Stream,
        direction: Direction,
        target_id: Id,
        flags: Flags,
        params: []const *const c.struct_spa_pod,
    ) !void {
        if (c.pw_stream_connect(
            stream.ptr,
            @intFromEnum(direction),
            @intFromEnum(target_id),
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
