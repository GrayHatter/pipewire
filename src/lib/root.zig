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

    /// use type void when the user ptr provided to pipewire is expected to be null
    pub fn ListenerFn(T: type) type {
        return *const fn (*T, Id, u32, ?Target, u32, SimplePlugin.Dict) void;
    }

    pub fn addListener(reg: Registry, T: type, comptime func: ListenerFn(T), reg_listener: *c.spa_hook, usrptr: *T) !void {
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
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    @as(Id, @enumFromInt(id)),
                    permissions,
                    if (name) |n| Target.fromStr(n) catch null else null,
                    version,
                    SimplePlugin.Dict.fromPw(props.?),
                });
            }
        };

        if (c.pw_registry_add_listener(reg.ptr, reg_listener, &.{
            .version = c.PW_VERSION_REGISTRY_EVENTS,
            .global = &CFunc.wrapper,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }

    pub const Target = enum {
        client,
        core,
        data_loop,
        data_system,
        device,
        factory,
        link,
        log,
        loop,
        loop_control,
        loop_utils,
        metadata,
        module,
        node,
        profiler,
        port,
        registry,
        security_context,
        system,
        thread_utils,

        pub fn toStr(t: Target) [*:0]const u8 {
            // TODO should this be PW_TYPE_INTERFACE_client?
            const pwif_prefix = "PipeWire:Interface:";
            return switch (t) {
                .client => pwif_prefix ++ "Client",
                .core => pwif_prefix ++ "Core",
                .data_loop => pwif_prefix ++ "DataLoop",
                .data_system => pwif_prefix ++ "DataSystem",
                .device => pwif_prefix ++ "Device",
                .factory => pwif_prefix ++ "Factory",
                .link => pwif_prefix ++ "Link",
                .log => pwif_prefix ++ "Log",
                .loop => pwif_prefix ++ "Loop",
                .loop_control => pwif_prefix ++ "LoopControl",
                .loop_utils => pwif_prefix ++ "LoopUtils",
                .metadata => pwif_prefix ++ "Metadata",
                .module => pwif_prefix ++ "Module",
                .node => pwif_prefix ++ "Node",
                .port => pwif_prefix ++ "Port",
                .profiler => pwif_prefix ++ "Profiler",
                .registry => pwif_prefix ++ "Registry",
                .security_context => pwif_prefix ++ "SecurityContext",
                .system => pwif_prefix ++ "System",
                .thread_utils => pwif_prefix ++ "ThreadUtils",
            };
        }

        pub fn fromStr(str_ptr: [*:0]const u8) !Target {
            const str = std.mem.span(str_ptr);
            if (std.mem.cutPrefix(u8, str, "PipeWire:Interface:")) |cut| {
                if (std.mem.eql(u8, cut, "Client")) {
                    return .client;
                } else if (std.mem.eql(u8, cut, "Core")) {
                    return .core;
                } else if (std.mem.eql(u8, cut, "DataLoop")) {
                    return .data_loop;
                } else if (std.mem.eql(u8, cut, "DataSystem")) {
                    return .data_system;
                } else if (std.mem.eql(u8, cut, "Device")) {
                    return .device;
                } else if (std.mem.eql(u8, cut, "Factory")) {
                    return .factory;
                } else if (std.mem.eql(u8, cut, "Link")) {
                    return .link;
                } else if (std.mem.eql(u8, cut, "Log")) {
                    return .log;
                } else if (std.mem.eql(u8, cut, "Loop")) {
                    return .loop;
                } else if (std.mem.eql(u8, cut, "LoopControl")) {
                    return .loop_control;
                } else if (std.mem.eql(u8, cut, "LoopUtils")) {
                    return .loop_utils;
                } else if (std.mem.eql(u8, cut, "Metadata")) {
                    return .metadata;
                } else if (std.mem.eql(u8, cut, "Module")) {
                    return .module;
                } else if (std.mem.eql(u8, cut, "Node")) {
                    return .node;
                } else if (std.mem.eql(u8, cut, "Port")) {
                    return .port;
                } else if (std.mem.eql(u8, cut, "Profiler")) {
                    return .profiler;
                } else if (std.mem.eql(u8, cut, "Registry")) {
                    return .registry;
                } else if (std.mem.eql(u8, cut, "SecurityContext")) {
                    return .security_context;
                } else if (std.mem.eql(u8, cut, "System")) {
                    return .system;
                } else if (std.mem.eql(u8, cut, "ThreadUtils")) {
                    return .thread_utils;
                }
            }

            return error.UnknownInterfaceTypeString;
        }
    };

    pub const Bind = union(Target) {
        client: Client,
        core: Core,
        data_loop: DataLoop,
        data_system: DataSystem,
        device: Device,
        factory: Factory,
        link: Link,
        log: Log,
        loop: Loop,
        loop_control: LoopControl,
        loop_utils: LoopUtils,
        metadata: Metadata,
        module: Module,
        node: Node,
        profiler: Profiler,
        port: Port,
        registry: Registry,
        security_context: SecurityContext,
        system: System,
        thread_utils: ThreadUtils,
    };

    pub fn bind(reg: Registry, target: Target, id: Id, ver: u32, size: usize) !Bind {
        // TODO what is size?

        const bind_proxy = c.pw_registry_bind(reg.ptr, @intFromEnum(id), target.toStr(), ver, size) orelse return error.UnableToBindToRegistry;

        return switch (target) {
            .client => .{ .client = .{ .ptr = @ptrCast(bind_proxy) } },
            .port => .{ .port = .{ .ptr = @ptrCast(bind_proxy) } },
            else => unreachable, // not implemented,
        };
    }

    pub fn raze(reg: Registry) void {
        // This is what the Pipewire examples do
        _ = c.pw_proxy_destroy(@ptrCast(@alignCast(reg.ptr)));
    }
};

/// Not yet implemented
pub const Port = struct {
    ptr: *c.pw_port,

    pub const Info = struct {
        id: Id,
        change_mask: u64,
        direction: Direction,
        props: SimplePlugin.Dict,
        params: []const SimplePlugin.Param,
    };

    pub fn PortFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
            params: ?*const fn (*T, ?*anyopaque, c_int, u32, u32, u32, [*c]const c.struct_spa_pod) void = null,
        };
    }

    //permissions: ?*const fn (?*anyopaque, u32, u32, [*c]const struct_pw_permission) callconv(.c) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, u32, u32, [*c]const struct_pw_permission) callconv(.c) void),

    pub fn addListener(port: Port, T: type, comptime func: PortFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, port_info: ?*const c.pw_port_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(port_info.?.id),
                        .change_mask = port_info.?.change_mask,
                        .direction = @enumFromInt(port_info.?.direction),
                        .props = SimplePlugin.Dict.fromPw(port_info.?.props),
                        .params = if (port_info.?.params) |parm| @as([*]const SimplePlugin.Param, @ptrCast(parm))[0..port_info.?.n_params] else &.{},
                    },
                });
            }

            fn params(ptr: ?*anyopaque, client_info: ?*const c.pw_client_info) callconv(.c) void {
                @call(.auto, func, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(client_info.?.id),
                        .change_mask = client_info.?.change_mask,
                        .props = SimplePlugin.Dict.fromPw(client_info.?.props),
                    },
                });
            }
        };

        if (c.pw_port_add_listener(port.ptr, listener, &.{
            .version = c.PW_VERSION_PORT_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }
};

pub const Client = struct {
    ptr: *c.pw_client,

    pub const Info = struct {
        id: Id,
        change_mask: u64,
        props: SimplePlugin.Dict,
    };

    pub fn ClientFn(T: type) type {
        return *const fn (*T, Client.Info) void;
    }

    //permissions: ?*const fn (?*anyopaque, u32, u32, [*c]const struct_pw_permission) callconv(.c) void = @import("std").mem.zeroes(?*const fn (?*anyopaque, u32, u32, [*c]const struct_pw_permission) callconv(.c) void),

    pub fn addListener(client: Client, T: type, comptime func: ClientFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, client_info: ?*const c.pw_client_info) callconv(.c) void {
                @call(.auto, func, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Client.Info{
                        .id = @enumFromInt(client_info.?.id),
                        .change_mask = client_info.?.change_mask,
                        .props = SimplePlugin.Dict.fromPw(client_info.?.props),
                    },
                });
            }
        };

        if (c.pw_client_add_listener(client.ptr, listener, &.{
            .version = c.PW_VERSION_CLIENT_EVENTS,
            .info = &CFunc.info,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
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
    pub const Dict = struct {
        flags: u32,
        items: []const Item,

        pub const Item = extern struct {
            key: [*:0]const u8,
            value: [*:0]const u8,
        };

        pub fn fromPw(props: *const c.spa_dict) Dict {
            if (props.items == null)
                std.debug.print("{any}\n", .{props});
            return .{
                .flags = props.flags,
                .items = if (props.n_items == 0 or props.items == null)
                    &.{}
                else
                    @as([*]const SimplePlugin.Dict.Item, @ptrCast(props.items))[0..props.n_items],
            };
        }
    };

    pub const Param = extern struct {
        id: u32,
        flags: u32,
        user: u32,
        seq: i32,
        padding: [4]u32,
    };

    pub const POD = PlainOldData;
    pub const PlainOldData = struct {
        pub const Builder = struct {};
    };
};

pub const Direction = enum(c_uint) {
    input = c.PW_DIRECTION_INPUT,
    output = c.PW_DIRECTION_OUTPUT,
};

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
            destroy: ?*const fn (*T) void = null,
            state_changed: ?*const fn (*T, State, State, ?[*:0]const u8) void = null, // old, new, err
            control_info: ?*const fn (*T, u32, *const c.pw_stream_control) void = null, // )(void *data, uint32_t id, const struct pw_stream_control *control)
            io_changed: ?*const fn (*T, u32, *anyopaque, u32) void = null, // )(void *data, uint32_t id, void *area, uint32_t size)
            param_changed: ?*const fn (*T, Id, *const c.spa_pod) void = null, // )(void *data, uint32_t id, const struct spa_pod *param)
            add_buffer: ?*const fn (*T, *c.pw_buffer) void = null, // )(void *data, struct pw_buffer *buffer)
            remove_buffer: ?*const fn (*T, *c.pw_buffer) void = null, // )(void *data, struct pw_buffer *buffer)
            process: ?*const fn (*T) void = null,
            drained: ?*const fn (*T) void = null,
            command: ?*const fn (*T, *const c.spa_command) void = null, // )(void *data, const struct spa_command *command)
            trigger_done: ?*const fn (*T) void = null, // )(void *data)
        };
    }

    pub fn simple(T: type, loop: Loop, name: [:0]const u8, props: Properties, comptime events: Events(T), usrptr: *T) !Stream {
        const CFunc = struct {
            fn process(ptr: ?*anyopaque) callconv(.c) void {
                if (comptime events.process) |proc|
                    @call(.auto, proc, .{@as(*T, @ptrCast(@alignCast(ptr)))});
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

/// Not yet implemented
pub const DataLoop = void;
/// Not yet implemented
pub const DataSystem = void;
/// Not yet implemented
pub const Device = void;
/// Not yet implemented
pub const Factory = void;
/// Not yet implemented
pub const Link = void;
/// Not yet implemented
pub const Log = void;
/// Not yet implemented
pub const LoopControl = void;
/// Not yet implemented
pub const LoopUtils = void;
/// Not yet implemented
pub const Metadata = void;
/// Not yet implemented
pub const Module = void;
/// Not yet implemented
pub const Node = void;
/// Not yet implemented
pub const Profiler = void;
/// Not yet implemented
pub const SecurityContext = void;
/// Not yet implemented
pub const System = void;
/// Not yet implemented
pub const ThreadUtils = void;

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
