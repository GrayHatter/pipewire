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

pub const Id = enum(u32) {
    core = 0,
    client = 1,
    any = std.math.maxInt(u32),
    _,

    pub fn id(int: u32) Id {
        return @enumFromInt(int);
    }
};

pub const Interface = union(Interface.Name) {
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

    pub const Name = enum {
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

        pub fn TypeFor(name: Name) type {
            inline for (@typeInfo(Interface).@"union".fields) |f| {
                if (std.mem.eql(u8, @tagName(name), f.name)) return f.type;
            }
            comptime unreachable;
        }

        pub fn toStr(name: Name) [*:0]const u8 {
            // TODO should this be PW_TYPE_INTERFACE_client?
            const pwif_prefix = "PipeWire:Interface:";
            return switch (name) {
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

        pub fn fromStr(str_ptr: [*:0]const u8) !Name {
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
};

pub const Sequence = enum(u31) {
    zero = 0,
    _,

    pub fn seq(int: i32) Sequence {
        std.debug.assert(int >= 0);
        return @enumFromInt(@as(u31, @intCast(int)));
    }
};

pub const MainLoop = struct {
    ptr: *c.pw_main_loop,
    /// Convenience var which can be used to track the current seq. Modified when `roundtrip`
    /// is called, and the previous value is restored IFF unmodified during the roundtrip.
    seq: Sequence = .zero,

    pub fn run(ml: MainLoop) !void {
        if (c.pw_main_loop_run(ml.ptr) != 0) return error.MainLoopRunFailed;
    }

    pub fn quit(ml: MainLoop) !void {
        if (c.pw_main_loop_quit(ml.ptr) < 0) return error.MainLoopQuitError; // Seems unlikely
    }

    fn roundtripSync(ml_ptr: ?*anyopaque, id: u32, seq_: i32) callconv(.c) void {
        const ml: *const MainLoop = @ptrCast(@alignCast(ml_ptr.?));
        const seq: Sequence = .seq(seq_);
        if (id == c.PW_ID_CORE and seq == ml.seq)
            ml.quit() catch unreachable;
    }

    /// Convenience function to issue a single roundtrip to pipewire. Exits when pipewire emits a
    /// `done` event for the seq number stored in `MainLoop.seq`. If you issue additional calls to
    /// pipewire during the roundtrip, update seq to the new number returned by that call.
    ///
    /// Note: Calls `quit` on `MainLoop` internally. Shouldn't be used within an already running loop
    pub fn roundtrip(ml: *MainLoop, core: Core) !void {
        const prev_seq = ml.seq;
        var rt_seq = ml.seq;
        defer {
            if (ml.seq == rt_seq) ml.seq = prev_seq;
        }

        var core_listener: c.spa_hook = undefined;
        if (c.pw_core_add_listener(core.ptr, &core_listener, &.{
            .version = c.PW_VERSION_CORE_EVENTS,
            .done = roundtripSync,
        }, ml) != 0) return error.UnableToAddCoreListener;
        defer _ = c.spa_hook_remove(&core_listener);

        rt_seq = try core.sync(.core, 0);
        ml.seq = rt_seq;

        const err = c.pw_main_loop_run(ml.ptr);
        if (err < 0) return error.RoundtripFailed;
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

    pub fn newContext(loop: Loop) !Context {
        return try .init(loop);
    }
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

    pub fn sync(core: Core, id: Id, seq: i32) !Sequence {
        const res = c.pw_core_sync(core.ptr, @intFromEnum(id), seq);
        if (res < 0) return error.CoreSyncFailed;
        return .seq(res);
    }

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
        return *const fn (*T, Id, u32, ?Interface.Name, u32, SimplePlugin.Dict) void;
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
                    if (name) |n| Interface.Name.fromStr(n) catch null else null,
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

    pub fn bind(reg: Registry, comptime target: Interface.Name, id: Id, ver: u32, size: usize) !target.TypeFor() {
        // TODO what is size?
        const bind_proxy = c.pw_registry_bind(reg.ptr, @intFromEnum(id), target.toStr(), ver, size) orelse return error.UnableToBindToRegistry;

        return switch (target) {
            .client => .{ .ptr = @ptrCast(bind_proxy) },
            .device => .{ .ptr = @ptrCast(bind_proxy) },
            .factory => .{ .ptr = @ptrCast(bind_proxy) },
            .link => .{ .ptr = @ptrCast(bind_proxy) },
            .metadata => .{ .ptr = @ptrCast(bind_proxy) },
            .module => .{ .ptr = @ptrCast(bind_proxy) },
            .node => .{ .ptr = @ptrCast(bind_proxy) },
            .port => .{ .ptr = @ptrCast(bind_proxy) },
            else => comptime unreachable, // not implemented,
        };
    }

    pub fn raze(reg: Registry) void {
        // This is what the Pipewire examples do
        _ = c.pw_proxy_destroy(@ptrCast(@alignCast(reg.ptr)));
    }
};

pub const Link = struct {
    ptr: *c.pw_link,

    pub const Info = struct {
        id: Id,
        output_node_id: Id,
        output_port_id: Id,
        input_node_id: Id,
        input_port_id: Id,
        change_mask: u64,
        state: State,
        error_str: ?[*:0]const u8,
        format: ?*const SimplePlugin.POD,
    };

    pub const State = enum(i32) {
        err = -2,
        unlinked = -1,
        init = 0,
        negotiating = 1,
        allocating = 2,
        paused = 3,
        active = 4,
    };

    pub fn LinkFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
        };
    }

    pub fn addListener(link: Link, T: type, comptime func: LinkFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, link_info: ?*const c.pw_link_info) callconv(.c) void {
                const l_info = link_info orelse unreachable;
                const format: ?*const c.spa_pod = l_info.format;
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(l_info.id),
                        .output_node_id = @enumFromInt(l_info.output_node_id),
                        .output_port_id = @enumFromInt(l_info.output_port_id),
                        .input_node_id = @enumFromInt(l_info.input_node_id),
                        .input_port_id = @enumFromInt(l_info.input_port_id),
                        .change_mask = l_info.change_mask,
                        .state = @enumFromInt(l_info.state),
                        .error_str = l_info.@"error",
                        .format = if (format) |fmt| @ptrCast(fmt) else null,
                    },
                });
            }
        };

        if (c.pw_link_add_listener(link.ptr, listener, &.{
            .version = c.PW_VERSION_LINK_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }
};

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
            param: ?*const fn (*T, Sequence, Id, u32, u32, [*]const SimplePlugin.POD) void = null,
        };
    }

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

            fn param(ptr: ?*anyopaque, seq: i32, id: u32, index: u32, next: u32, data: [*]const c.spa_pod) callconv(.c) void {
                @call(.auto, func, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Sequence.seq(seq),
                    @as(SimplePlugin.Param.Id, @enumFromInt(id)),
                    index,
                    next,
                    @as([*]const SimplePlugin.POD, @ptrCast(data)),
                });
            }
        };

        if (c.pw_port_add_listener(port.ptr, listener, &.{
            .version = c.PW_VERSION_PORT_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
            .param = if (func.param != null) &CFunc.param else null,
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
        return struct {
            info: ?*const fn (*T, Client.Info) void = null,
            permissions: ?*const fn (*T, Id, []const Permission) void = null,
        };
    }

    pub fn addListener(client: Client, T: type, comptime func: ClientFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, client_info: ?*const c.pw_client_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Client.Info{
                        .id = @enumFromInt(client_info.?.id),
                        .change_mask = client_info.?.change_mask,
                        .props = SimplePlugin.Dict.fromPw(client_info.?.props),
                    },
                });
            }

            fn permissions(ptr: ?*anyopaque, count: u33, perms: ?[*]const c.pw_permission) callconv(.c) void {
                @call(.auto, func.permissions.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Permission.fromPw(perms, count),
                });
            }
        };

        if (c.pw_client_add_listener(client.ptr, listener, &.{
            .version = c.PW_VERSION_CLIENT_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
            .permissions = if (func.permissions != null) &CFunc.permissions else null,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }
};

pub const Device = struct {
    ptr: *c.pw_device,

    pub const Info = struct {
        id: Id,
        change_mask: u64,
        params: []const SimplePlugin.Param,
    };

    pub fn DeviceFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
            param: ?*const fn (*T, ?*anyopaque, Sequence, u32, u32, u32, [*c]const c.struct_spa_pod) void = null,
        };
    }

    pub fn addListener(dev: Device, T: type, comptime func: DeviceFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, dev_info: ?*const c.pw_device_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(dev_info.?.id),
                        .change_mask = dev_info.?.change_mask,
                        .params = SimplePlugin.Param.fromPw(dev_info.?.params, dev_info.?.n_params),
                    },
                });
            }

            fn param(ptr: ?*anyopaque, seq: i32, id: u32, index: u32, next: u32, params: [*]const c.spa_pod) callconv(.c) void {
                @call(.auto, func.param.?, .{ @as(*T, @ptrCast(@alignCast(ptr))), seq, id, index, next, params });
            }
        };

        if (c.pw_device_add_listener(dev.ptr, listener, &.{
            .version = c.PW_VERSION_DEVICE_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
            .param = if (func.param != null) &CFunc.param else null,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }
};

pub const Factory = struct {
    ptr: *c.pw_factory,

    pub const Info = struct {
        id: Id,
        type: ?[:0]const u8,
        version: u32,
        change_mask: u64,
    };

    pub fn FactoryFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
        };
    }

    pub fn addListener(fact: Factory, T: type, comptime func: FactoryFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, fact_info: ?*const c.pw_factory_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(fact_info.?.id),
                        .type = if (fact_info.?.type) |typ| std.mem.span(typ) else null,
                        .version = fact_info.?.version,
                        .change_mask = fact_info.?.change_mask,
                    },
                });
            }
        };

        if (c.pw_factory_add_listener(fact.ptr, listener, &.{
            .version = c.PW_VERSION_FACTORY_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
        }, usrptr) != 0) return error.UnableToAddFactoryListener;
    }
};

/// `Metadata` is an extension
pub const Metadata = struct {
    ptr: *c.pw_proxy,

    pub fn MetadataFn(T: type) type {
        return struct {
            property: ?*const fn (*T, Id, ?[:0]const u8, ?[:0]const u8, ?[:0]const u8) i32 = null,
        };
    }

    pub fn addListener(meta: Metadata, T: type, comptime func: MetadataFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn property(ptr: ?*anyopaque, id: u32, key: ?[*:0]const u8, md_type: ?[*:0]const u8, value: ?[*:0]const u8) callconv(.c) c_int {
                return @call(.auto, func.property.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Id.id(id),
                    if (key) |k| std.mem.span(k) else null,
                    if (md_type) |t| std.mem.span(t) else null,
                    if (value) |v| std.mem.span(v) else null,
                });
            }
        };

        const iface: *c.spa_interface = @ptrCast(@alignCast(meta.ptr));
        const callbacks: *const c.pw_metadata_methods = @ptrCast(@alignCast(iface.cb.funcs));
        _ = callbacks.add_listener(iface.cb.data.?, listener, &.{
            .version = c.PW_VERSION_METADATA_EVENTS,
            .property = if (func.property != null) &CFunc.property else null,
        }, usrptr);
    }

    pub fn setProperty(meta: Metadata, target: Id, key: [:0]const u8, md_type: [:0]const u8, value: [:0]const u8) !void {
        const iface: *c.spa_interface = @ptrCast(@alignCast(meta.ptr));
        const callbacks: *const c.pw_metadata_methods = @ptrCast(@alignCast(iface.cb.funcs));
        _ = callbacks.set_property(iface.cb.data.?, @intFromEnum(target), key, md_type, value);
    }
};

pub const Module = struct {
    ptr: *c.pw_module,

    pub const Info = struct {
        id: Id,
        filename: ?[:0]const u8,
        args: ?[:0]const u8,
        change_mask: u64,
    };

    pub fn ModuleFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
        };
    }

    pub fn addListener(dev: Module, T: type, comptime func: ModuleFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, mod_info: ?*const c.pw_module_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(mod_info.?.id),
                        .filename = if (mod_info.?.filename) |fname| std.mem.span(fname) else null,
                        .args = if (mod_info.?.args) |args| std.mem.span(args) else null,
                        .change_mask = mod_info.?.change_mask,
                    },
                });
            }
        };

        if (c.pw_module_add_listener(dev.ptr, listener, &.{
            .version = c.PW_VERSION_MODULE_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
        }, usrptr) != 0) return error.UnableToAddModuleListener;
    }
};

pub const Node = struct {
    ptr: *c.pw_node,

    pub const Info = struct {
        id: Id,
        input_ports_max: u32,
        output_ports_max: u32,
        change_mask: Changes,
        input_ports_count: u32,
        output_ports_count: u32,
        state: State,
        error_str: ?[*:0]const u8,
        props: SimplePlugin.Dict,
        params: []const SimplePlugin.Param,
    };

    pub const State = enum(i32) {
        err = -1,
        creating = 0,
        suspended = 1,
        idle = 2,
        running = 3,
        _,
    };

    pub const Changes = packed struct(u64) {
        input_ports: bool,
        output_ports: bool,
        state: bool,
        props: bool,
        params: bool,
        _: u59 = 0,

        pub const all: Changes = .{
            .input_ports = 1,
            .output_ports = 1,
            .state = 1,
            .props = 1,
            .params = 1,
        };

        pub const none: Changes = .{
            .input_ports = 0,
            .output_ports = 0,
            .state = 0,
            .props = 0,
            .params = 0,
        };
    };

    pub fn NodeFn(T: type) type {
        return struct {
            info: ?*const fn (*T, Info) void = null,
            param: ?*const fn (*T, Sequence, SimplePlugin.Param.Id, u32, u32, [*]const SimplePlugin.POD) void = null,
        };
    }

    pub fn addListener(dev: Node, T: type, comptime func: NodeFn(T), listener: *c.spa_hook, usrptr: *T) !void {
        const CFunc = struct {
            fn info(ptr: ?*anyopaque, node_info: ?*const c.pw_node_info) callconv(.c) void {
                @call(.auto, func.info.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Info{
                        .id = @enumFromInt(node_info.?.id),
                        .input_ports_max = node_info.?.max_input_ports,
                        .output_ports_max = node_info.?.max_output_ports,
                        .change_mask = @bitCast(node_info.?.change_mask),
                        .input_ports_count = node_info.?.n_input_ports,
                        .output_ports_count = node_info.?.n_output_ports,
                        .state = @enumFromInt(node_info.?.state),
                        .error_str = node_info.?.@"error",
                        .props = SimplePlugin.Dict.fromPw(node_info.?.props),
                        .params = SimplePlugin.Param.fromPw(node_info.?.params, node_info.?.n_params),
                    },
                });
            }

            fn param(ptr: ?*anyopaque, seq: i32, id: u32, index: u32, next: u32, data: ?[*]const c.spa_pod) callconv(.c) void {
                @call(.auto, func.param.?, .{
                    @as(*T, @ptrCast(@alignCast(ptr))),
                    Sequence.seq(seq),
                    @as(SimplePlugin.Param.Id, @enumFromInt(id)),
                    index,
                    next,
                    @as([*]const SimplePlugin.POD, @ptrCast(data)),
                });
            }
        };

        if (c.pw_node_add_listener(dev.ptr, listener, &.{
            .version = c.PW_VERSION_NODE_EVENTS,
            .info = if (func.info != null) &CFunc.info else null,
            .param = if (func.param != null) &CFunc.param else null,
        }, usrptr) != 0) return error.UnableToAddRegisteryListener;
    }

    pub fn enumParams(node: Node, seq: Sequence, id: SimplePlugin.Param.Id, start: u32, max: u32, filter: []const SimplePlugin.POD) !Sequence {
        if (filter.len != 0) return error.FilterNotImplemented;
        const res = c.pw_node_enum_params(node.ptr, @intFromEnum(seq), @intFromEnum(id), start, max, null);
        if (res < 0) {
            std.debug.print("Node enum prams failure {} : {} {} {} {}\n", .{ res, seq, id, start, max });
            return error.EnumerationFailed;
        }
        return .seq(res);
    }

    pub fn setParam(node: Node, param_id: SimplePlugin.Param.Id, flags: u32, params: *const c.struct_spa_pod) !Sequence {
        const res = c.pw_node_set_param(node.ptr, @intFromEnum(param_id), flags, @ptrCast(params));
        if (res < 0) {
            std.debug.print("Node set param failure {}\n", .{res});
            return error.SetParamFailed;
        }
        return .seq(res);
    }
};

pub const Properties = struct {
    ptr: *c.pw_properties,

    pub fn init(comptime kv: []const [*:0]const u8) !Properties {
        //const len = comptime std.mem.span(key_values).len;
        comptime std.debug.assert(kv.len & 1 == 0);
        //const Args = @Tuple([kv.len:null]?[*:0]const u8;
        const size = kv.len + 1;
        var args: @Tuple(&@as([size]type, @splat(?[*:0]const u8))) = undefined;
        inline for (kv, 0..) |src, i| {
            args[i] = src;
        } else args[kv.len] = null;
        const props: ?*c.pw_properties = @call(.auto, c.pw_properties_new, args);
        return .{ .ptr = props orelse return error.UnableToCReateProperties };
    }
};

/// Alias to SimplePlugin used throughout Pipewire.
pub const SPA = SimplePlugin;

/// Known through out Pipewire as SPA, or Simple Plugin API.
///
/// SPA also has a way to encode asynchronous results. This is done by setting a high bit
/// (bit 30, the ASYNC_BIT) in the result code and a sequence number in the lower bits.
/// This result is normally identified as a positive success result code and the sequence
/// number can later be matched to the completion event.
pub const SimplePlugin = struct {
    pub const Dict = struct {
        flags: u32,
        items: []const Item,

        pub const Item = extern struct {
            key: [*:0]const u8,
            value: [*:0]const u8,
        };

        pub fn fromPw(props: *const c.spa_dict) Dict {
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
        id: Param.Id,
        flags: u32,
        user: u32,
        seq: i32,
        padding: [4]u32,

        // flags hold at least RW bits but perhaps more?
        pub const Info = struct {
            pub const Permissions = struct {
                pub fn read(flags: u32) bool {
                    return (flags & 1) != 0;
                }

                pub fn write(flags: u32) bool {
                    return (flags & 2) != 0;
                }
            };
        };

        pub const Id = enum(u32) {
            invalid = 0,
            prop_info = 1,
            props = 2,
            enum_format = 3,
            format = 4,
            buffers = 5,
            meta = 6,
            io = 7,
            enum_profile = 8,
            profile = 9,
            enum_port_config = 10,
            port_config = 11,
            enum_route = 12,
            route = 13,
            control = 14,
            latency = 15,
            process_latency = 16,
            tag = 17,
            peer_formats = 18,
            _,

            pub fn PodType(id: Param.Id) type {
                return switch (id) {
                    .invalid => enum(u32) { nothing, _ }, // not implemented
                    .prop_info => POD.PropInfo,
                    .props => POD.Prop,
                    .enum_format => POD.Format,
                    .format => POD.Format,
                    .buffers => POD.Buffers,
                    .meta => POD.Meta,
                    .io => POD.Io,
                    .enum_profile => POD.Profile,
                    .profile => POD.Profile,
                    .enum_port_config => POD.PortConfig,
                    .port_config => POD.PortConfig,
                    .enum_route => POD.Route,
                    .route => POD.Route,
                    .control => enum(u32) { nothing, _ }, // SPA_PARAM_Control doesn't exist
                    .latency => POD.Latency,
                    .process_latency => POD.ProcessLatency,
                    .tag => POD.Tag,
                    .peer_formats => POD.Format, // Unvalidated, but seems likely?
                    _ => unreachable,
                };
            }
        };

        pub fn fromPw(ptr: ?[*]const c.spa_param_info, len: usize) []const Param {
            if (len == 0) return &.{};

            const params: [*]const Param = @ptrCast(ptr.?);
            return params[0..len];
        }
    };

    pub const POD = PlainOldData;
    pub const PlainOldData = extern struct {
        size: u32,
        type: Type,

        pub const Frame = struct {};

        /// Pipewire grossly overloads key for POD types. To reduce the codebloat that may result
        /// from comptime type enforcment of runtime only data. `Key` is provided as an easy
        /// translation layer between the various types.
        pub const Key = enum(u32) {
            _,

            pub fn format(f: Format) Key {
                return @enumFromInt(@intFromEnum(f));
            }

            pub fn portConfig(p: PortConfig) Key {
                return @enumFromInt(@intFromEnum(p));
            }

            pub fn prop(p: Prop) Key {
                return @enumFromInt(@intFromEnum(p));
            }

            pub fn toParamId(k: Key, id: Param.Id) void {
                _ = k;
                _ = id;
            }

            pub fn fmt(k: Key, id: Param.Id) Formatter {
                return .{ .k = k, .id = id };
            }

            pub const Formatter = struct {
                k: Key,
                id: Param.Id,

                pub fn format(self: @This(), w: *std.Io.Writer) !void {
                    switch (self.id) {
                        inline else => |t| {
                            const subtag: t.PodType() = @enumFromInt(@intFromEnum(self.k));
                            try w.print("{s}{}", .{ @tagName(t), subtag });
                        },
                        _ => {
                            try w.print("unknown key type {} ({})", .{ self.id, @intFromEnum(self.k) });
                        },
                    }
                }
            };
        };

        const Type = enum(u32) {
            none = 1,
            bool = 2,
            id = 3,
            int = 4,
            long = 5,
            float = 6,
            double = 7,
            string = 8,
            bytes = 9,
            rectangle = 10,
            fraction = 11,
            bitmap = 12,
            array = 13,
            @"struct" = 14,
            object = 15,
            sequence = 16,
            pointer = 17,
            fd = 18,
            choice = 19,
            pod = 20,
            _,

            pub fn TypeFor(t: Type) type {
                inline for (@typeInfo(Kind).@"union".fields) |f| {
                    if (std.mem.eql(u8, @tagName(t), f.name)) return f.type;
                }
                comptime unreachable;
            }
        };

        pub const Kind = union(Type) {
            none: void,
            bool: bool,
            /// May be different from the global interface Id,
            id: u32,
            int: i32,
            long: i64,
            float: f32,
            double: f64,
            string: [:0]const u8,
            bytes: [*]const u8,
            rectangle: Rectangle,
            fraction: Fraction,
            bitmap: Bitmap,
            array: Array,
            @"struct": Struct,
            object: Object,
            sequence: Sequence,
            pointer: Pointer,
            fd: i64,
            choice: Choice,
            pod: void, // 20?

            pub fn init(t: Type, size: usize, r: *std.Io.Reader) !Kind {
                return switch (t) {
                    .none => unreachable,
                    .bool => .{ .bool = (try r.takeInt(u32, .native) != 0) },
                    .id => .{ .id = try r.takeInt(u32, .native) },
                    .int => .{ .int = try r.takeInt(i32, .native) },
                    .long => .{ .long = try r.takeInt(i64, .native) },
                    .float => .{ .float = @as(*const f32, @ptrCast(@alignCast(try r.takeArray(4)))).* },
                    .double => .{ .double = @as(*const f64, @ptrCast(@alignCast(try r.takeArray(8)))).* },
                    .string => .{ .string = (try r.take(size))[0 .. size - 1 :0] },
                    .bytes => unreachable,
                    .rectangle => unreachable,
                    .fraction => unreachable,
                    .bitmap => unreachable,
                    .array => .{ .array = .init(try r.take(size)) },
                    .@"struct" => .{ .@"struct" = .init(try r.take(size)) },
                    .object => .{ .object = .init(@ptrCast(@alignCast(try r.take(size)))) },
                    .sequence => unreachable,
                    .pointer => unreachable,
                    .fd => unreachable,
                    .choice => .{ .choice = .init(try r.take(size)) },
                    .pod => unreachable,
                    _ => {
                        std.debug.print("KIND ERROR, {} {} {} {any}\n{}: {any}\n", .{ t, @as(u32, @intFromEnum(t)), size, r.buffered(), r.seek, r.buffer });
                        unreachable;
                    },
                };
            }
        };

        pub const Format = enum(u32) {
            START = 0,
            media_type = 1,
            media_subtype = 2,
            START_AUDIO = 65536,
            audio_format = 65537,
            audio_flags = 65538,
            audio_rate = 65539,
            audio_channels = 65540,
            audio_position = 65541,
            audio_iec958codec = 65542,
            audio_bitorder = 65543,
            audio_interleave = 65544,
            audio_bitrate = 65545,
            audio_block_align = 65546,
            audio_aac_stream_format = 65547,
            audio_wma_profile = 65548,
            audio_amr_band_mode = 65549,
            audio_mp3_channel_mode = 65550,
            audio_dts_ext_type = 65551,
            START_VIDEO = 131072,
            video_format = 131073,
            video_modifier = 131074,
            video_size = 131075,
            video_framerate = 131076,
            video_max_framerate = 131077,
            video_views = 131078,
            video_interlace_mode = 131079,
            video_pixel_aspect_ratio = 131080,
            video_multiview_mode = 131081,
            video_multiview_flags = 131082,
            video_chroma_site = 131083,
            video_color_range = 131084,
            video_color_matrix = 131085,
            video_transfer_function = 131086,
            video_color_primaries = 131087,
            video_profile = 131088,
            video_level = 131089,
            video_h264_stream_format = 131090,
            video_h264_alignment = 131091,
            video_h265_stream_format = 131092,
            video_h265_alignment = 131093,
            START_IMAGE = 196608,
            START_BINARY = 262144,
            START_STREAM = 327680,
            START_APPLICATION = 393216,
            control_types = 393217,
        };

        pub const Buffers = enum(u32) {
            START = 0,
            buffers = 1,
            blocks = 2,
            size = 3,
            stride = 4,
            @"align" = 5,
            dataType = 6,
            metaType = 7,
            _,
        };

        pub const Meta = enum(u32) {
            START = 0,
            type = 1,
            size = 2,
            features = 3,
            _,
        };

        pub const Io = enum(u32) {
            START = 0,
            id = 1,
            size = 2,
            _,
        };

        pub const Profile = enum(u32) {
            START = 0,
            index = 1,
            name = 2,
            description = 3,
            priority = 4,
            available = 5,
            info = 6,
            classes = 7,
            save = 8,
            _,
        };

        pub const PortConfigMode = enum(u32) {
            none = 0,
            passthrough = 1,
            convert = 2,
            dsp = 3,
        };

        pub const PortConfig = enum(u32) {
            direction = 1,
            mode = 2,
            monitor = 3,
            control = 4,
            format = 5,
        };

        pub const Route = enum(u32) {
            START = 0,
            index = 1,
            direction = 2,
            device = 3,
            name = 4,
            description = 5,
            priority = 6,
            available = 7,
            info = 8,
            profiles = 9,
            props = 10,
            devices = 11,
            profile = 12,
            save = 13,
            _,
        };

        pub const Tag = enum(u32) {
            START = 0,
            direction = 1,
            info = 2,
            _,
        };

        pub const PropInfo = enum(u32) {
            START = 0,
            id = 1,
            name = 2,
            type = 3,
            labels = 4,
            container = 5,
            params = 6,
            description = 7,
        };

        pub const Prop = enum(u32) {
            START = 0,
            unknown = 1,
            START_Device = 256,
            device = 257,
            device_Name = 258,
            device_fd = 259,
            card = 260,
            card_name = 261,
            min_latency = 262,
            max_latency = 263,
            periods = 264,
            period_size = 265,
            period_event = 266,
            live = 267,
            rate = 268,
            quality = 269,
            bluetooth_audio_codec = 270,
            bluetooth_offload_active = 271,
            START_Audio = 65536,
            wave_type = 65537,
            frequency = 65538,
            volume = 65539,
            mute = 65540,
            pattern_type = 65541,
            dither_type = 65542,
            truncate = 65543,
            channel_volumes = 65544,
            volume_base = 65545,
            volume_step = 65546,
            channel_map = 65547,
            monitor_mute = 65548,
            monitor_volumes = 65549,
            latency_offset_nsec = 65550,
            soft_mute = 65551,
            soft_volumes = 65552,
            iec958_codecs = 65553,
            volume_ramp_samples = 65554,
            volume_ramp_step_samples = 65555,
            volume_ramp_time = 65556,
            volume_ramp_step_time = 65557,
            volume_ramp_scale = 65558,
            START_Video = 131072,
            brightness = 131073,
            contrast = 131074,
            saturation = 131075,
            hue = 131076,
            gamma = 131077,
            exposure = 131078,
            gain = 131079,
            sharpness = 131080,
            START_Other = 524288,
            params = 524289,
            START_CUSTOM = 16777216,
        };

        pub const Latency = enum(u32) {
            START = 0,
            direction = 1,
            min_quantum = 2,
            max_quantum = 3,
            min_rate = 4,
            max_rate = 5,
            min_ns = 6,
            max_ns = 7,
        };

        pub const ProcessLatency = enum(u32) {
            START = 0,
            quantum = 1,
            rate = 2,
            ns = 3,
        };

        pub const Rectangle = struct { width: u32, height: u32 };

        pub const Fraction = struct { num: u32, dom: u32 };

        pub const Object = struct {
            bytes: []align(8) const u8,
            type: Object.Type,
            id: Param.Id,
            reader: std.Io.Reader,

            pub const Type = enum(u32) {
                prop_info = 262145,
                props = 262146,
                format = 262147,
                param_buffers = 262148,
                param_meta = 262149,
                param_io = 262150,
                param_profile = 262151,
                param_port_config = 262152,
                param_route = 262153,
                profiler = 262154,
                param_latency = 262155,
                param_process_latency = 262156,
                param_tag = 262157,
                _,
                pub const START: Object.Type = @enumFromInt(262144);
                pub const LAST: Object.Type = @enumFromInt(262158);
            };

            pub const Flags = packed struct(u32) {
                _: u32 = 0,

                pub const none: Flags = .{};
            };

            pub fn fromPod(pod: *const POD) Object {
                const bytes: [*]align(8) const u8 = @ptrCast(@alignCast(pod));
                const size = pod.size;

                var reader: std.Io.Reader = .fixed(bytes[0..size]);
                const pod_size = reader.takeInt(u32, .native) catch unreachable;
                const pod_type = reader.takeEnumNonexhaustive(POD.Type, .native) catch unreachable;
                _ = pod_type;
                return .init(bytes[8..][0..pod_size]);
            }

            pub fn init(bytes: []const u8) Object {
                var reader: std.Io.Reader = .fixed(bytes[0..]);
                const obj_type = reader.takeEnumNonexhaustive(Object.Type, .native) catch unreachable;
                const obj_id = reader.takeEnumNonexhaustive(Param.Id, .native) catch unreachable;

                return .{
                    .bytes = @alignCast(bytes),
                    .type = obj_type,
                    .id = obj_id,
                    .reader = reader,
                };
            }

            pub const Result = struct {
                key: Key,
                flags: Flags,
                type: POD.Type,
                value: Kind,
            };

            pub fn next(obj: *Object) ?Result {
                const key = obj.reader.takeEnum(Key, .native) catch return null;
                const flags = obj.reader.takeStruct(Flags, .native) catch unreachable;
                const value_size = obj.reader.takeInt(u32, .native) catch unreachable;
                const value_type = obj.reader.takeEnumNonexhaustive(POD.Type, .native) catch unreachable;
                defer while (obj.reader.seek % 8 != 0) {
                    //std.debug.print("tossing {x}\n", .{obj.reader.takeByte() catch unreachable});
                    obj.reader.toss(1);
                };

                return .{
                    .key = key,
                    .flags = flags,
                    .type = value_type,
                    .value = Kind.init(value_type, value_size, &obj.reader) catch unreachable,
                };
            }

            pub const Builder = struct {
                builder: *POD.Builder,
                body: []align(8) u8,

                pub fn append(obj: *Object.Builder, key: Key, flags: Flags, comptime kind: POD.Type, value: anytype) !void {
                    var buffer: [256]u8 = undefined; // TODO size array correctly
                    var writer: std.Io.Writer = .fixed(&buffer);
                    const padding: u32 = 0;
                    writer.writeInt(u32, @intFromEnum(key), .native) catch return error.NoSpaceLeft;
                    writer.writeInt(u32, @bitCast(flags), .native) catch return error.NoSpaceLeft;
                    switch (kind) {
                        .id => {
                            writer.writeInt(u32, 4, .native) catch return error.NoSpaceLeft; // size
                            writer.writeInt(u32, @intFromEnum(kind), .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, @bitCast(value), .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, padding, .native) catch return error.NoSpaceLeft;
                        },

                        .int => {
                            writer.writeInt(u32, 4, .native) catch return error.NoSpaceLeft; // size
                            writer.writeInt(u32, @intFromEnum(kind), .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, @bitCast(value), .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, padding, .native) catch return error.NoSpaceLeft;
                        },
                        .array => {
                            // TODO construct sane api instead of this monstrosity
                            const child_type: POD.Type = value[0];
                            const array: []const child_type.TypeFor() = value[1];
                            const array_size: usize = (@sizeOf(child_type.TypeFor()) * array.len);

                            writer.writeInt(u32, array_size + 8, .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, @intFromEnum(kind), .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, array_size, .native) catch return error.NoSpaceLeft;
                            writer.writeInt(u32, @intFromEnum(child_type), .native) catch return error.NoSpaceLeft;

                            for (array) |item|
                                writer.writeAll(std.mem.asBytes(&item)) catch return error.NoSpaceLeft;

                            for (array_size..array_size + 7 & ~@as(usize, 7)) |_|
                                writer.writeByte(0) catch return error.NoSpaceLeft;
                        },
                        .object => unreachable, // TODO
                        else => comptime unreachable, // not implemented,
                        _ => comptime unreachable,
                    }

                    obj.body = try obj.builder.append(obj.body, writer.buffered());
                }

                pub fn toPwPod(obj: *Object.Builder) *c.spa_pod {
                    return @ptrCast(obj.body);
                }

                pub fn toPwPodFrame(obj: *Object.Builder) *c.spa_pod_frame {
                    return @ptrCast(obj.body);
                }
            };
        };

        pub const Array = struct {
            bytes: []const u8,
            size: u32,
            type: POD.Type,
            reader: std.Io.Reader,

            pub fn init(bytes: []const u8) Array {
                var reader: std.Io.Reader = .fixed(bytes);
                const size = reader.takeInt(u32, .native) catch unreachable;
                const ctype = reader.takeEnum(POD.Type, .native) catch unreachable;
                return .{
                    .bytes = bytes,
                    .size = size,
                    .type = ctype,
                    .reader = reader,
                };
            }

            pub fn next(arr: *Array) ?Kind {
                if (arr.reader.bufferedLen() == 0) return null;
                return Kind.init(arr.type, arr.size, &arr.reader) catch null;
            }
        };

        pub const Choice = struct {
            bytes: []const u8,
            type: Choice.Type,
            flags: u32,
            child_type: POD.Type,
            child_size: u32,
            reader: std.Io.Reader,

            pub const Type = enum(u32) {
                /// None (0) : only child1 is an valid option
                none = 0,
                /// Range (1) : child1 is a default value, options are between child2 and child3 in the value array.
                range = 1,
                /// Step (2) : child1 is a default value, options are between child2 and child3, in steps of child4 in the value array.
                step = 2,
                /// Enum (3) : child1 is a default value, options are any value from the value array, preferred values come first.
                @"enum" = 3,
                /// Flags (4) : child1 is a default value, options are any value from the value array, preferred values come first.
                flags = 4,
            };

            pub fn init(bytes: []const u8) Choice {
                var reader: std.Io.Reader = .fixed(bytes);
                const ctype = reader.takeEnum(Choice.Type, .native) catch unreachable;
                const cflags = reader.takeInt(u32, .native) catch unreachable;
                const child_size = reader.takeInt(u32, .native) catch unreachable;
                const child_type = reader.takeEnum(POD.Type, .native) catch unreachable;
                return .{
                    .bytes = bytes,
                    .type = ctype,
                    .flags = cflags,
                    .child_type = child_type,
                    .child_size = child_size,
                    .reader = reader,
                };
            }

            pub fn next(choice: *Choice) ?Kind {
                if (choice.reader.bufferedLen() == 0) return null;
                return Kind.init(choice.child_type, choice.child_size, &choice.reader) catch unreachable;
            }
        };

        pub const Struct = struct {
            bytes: []const u8,
            reader: std.Io.Reader,

            pub fn init(bytes: []const u8) Struct {
                return .{
                    .bytes = bytes,
                    .reader = .fixed(bytes),
                };
            }

            pub fn next(st: *Struct) ?Kind {
                if (st.reader.bufferedLen() == 0) return null;
                defer while (st.reader.seek % 8 != 0) st.reader.toss(1);

                const child_size = st.reader.takeInt(u32, .native) catch unreachable;
                const child_type = st.reader.takeEnum(POD.Type, .native) catch unreachable;
                return Kind.init(child_type, child_size, &st.reader) catch null;
            }
        };

        pub const Bitmap = void;
        pub const Pointer = void;

        pub const Builder = struct {
            bytes: []align(8) u8,
            len: usize = 0,

            pub const Flags = packed struct(u32) {
                _: u32 = 0,

                pub const none: Flags = .{};
            };

            pub fn init(buffer: []align(8) u8) Builder {
                return .{ .bytes = buffer };
            }

            pub fn pushObject(build: *Builder, obj_type: Object.Type, obj_id: Param.Id) error{NoSpaceLeft}!Object.Builder {
                std.debug.assert(build.len % 8 == 0);
                var body: []align(8) u8 = @alignCast(build.bytes[build.len..]);
                const empty_size = 8;
                var writer: std.Io.Writer = .fixed(body);
                writer.writeInt(u32, empty_size, .native) catch return error.NoSpaceLeft;
                writer.writeInt(u32, @intFromEnum(POD.Type.object), .native) catch return error.NoSpaceLeft;
                writer.writeInt(u32, @intFromEnum(obj_type), .native) catch return error.NoSpaceLeft;
                writer.writeInt(u32, @intFromEnum(obj_id), .native) catch return error.NoSpaceLeft;
                return .{
                    .builder = build,
                    .body = body[0 .. 8 + empty_size],
                };
            }

            fn append(build: *Builder, frame: []align(8) u8, new: []const u8) error{NoSpaceLeft}![]align(8) u8 {
                if (new.len + build.len > build.bytes.len) return error.NoSpaceLeft;
                const orig_frame_size = std.mem.readInt(u32, frame[0..4], .native);
                var body: []align(8) u8 = frame;
                build.len += new.len;
                body.len += new.len;
                @memcpy(body[frame.len..], new);

                std.mem.writeInt(u32, body[0..4], @intCast(orig_frame_size + new.len), .native);
                return body;
            }

            pub fn pop(build: *Builder) Frame {
                _ = build;
                return .{};
            }
        };

        test Builder {
            var c_pod_buffer: [2048]u8 align(8) = undefined;
            var pod_builder: c.spa_pod_builder = .{ .data = &c_pod_buffer, .size = c_pod_buffer.len };
            var frame: c.spa_pod_frame = undefined;
            _ = c.spa_pod_builder_push_object(&pod_builder, &frame, c.SPA_TYPE_OBJECT_Format, c.SPA_PARAM_EnumFormat);
            _ = c.spa_pod_builder_prop(&pod_builder, c.SPA_FORMAT_mediaType, 0);
            _ = c.spa_pod_builder_id(&pod_builder, c.SPA_MEDIA_TYPE_audio);
            _ = c.spa_pod_builder_prop(&pod_builder, c.SPA_FORMAT_mediaSubtype, 0);
            _ = c.spa_pod_builder_id(&pod_builder, c.SPA_MEDIA_SUBTYPE_raw);
            _ = c.spa_pod_builder_prop(&pod_builder, c.SPA_FORMAT_AUDIO_format, 0);
            _ = c.spa_pod_builder_id(&pod_builder, c.SPA_AUDIO_FORMAT_F32);
            _ = c.spa_pod_builder_prop(&pod_builder, c.SPA_FORMAT_AUDIO_rate, 0);
            _ = c.spa_pod_builder_int(&pod_builder, 48000);
            _ = c.spa_pod_builder_prop(&pod_builder, c.SPA_FORMAT_AUDIO_channels, 0);
            _ = c.spa_pod_builder_int(&pod_builder, 2);
            _ = c.spa_pod_builder_pop(&pod_builder, &frame).?;

            var zig_pod_buffer: [2048]u8 align(8) = undefined;
            var builder: Builder = .init(&zig_pod_buffer);
            var zig_frame = try builder.pushObject(.format, .enum_format);
            try zig_frame.append(.format(.media_type), .none, .id, c.SPA_MEDIA_TYPE_audio);
            try zig_frame.append(.format(.media_subtype), .none, .id, c.SPA_MEDIA_SUBTYPE_raw);
            try zig_frame.append(.format(.audio_format), .none, .id, c.SPA_AUDIO_FORMAT_F32);
            try zig_frame.append(.format(.audio_rate), .none, .int, @as(u32, 48000));
            try zig_frame.append(.format(.audio_channels), .none, .int, @as(u32, 2));

            try std.testing.expectEqual(&zig_pod_buffer, @as([*]u8, @ptrCast(zig_frame.toPwPod())));
            try std.testing.expectEqual(c.spa_pod{ .size = 128, .type = 15 }, zig_frame.toPwPod().*);

            try std.testing.expectEqualSlices(u8, &c_pod_buffer, &zig_pod_buffer);
        }

        pub fn init(pod: *const POD) Kind {
            switch (pod.type) {
                .object => return .{ .object = Object.fromPod(pod) },

                else => unreachable, // not implemented
            }
        }
    };

    test {
        _ = &std.testing.refAllDecls(@This());
    }
};

pub const Direction = enum(c_uint) {
    input = c.PW_DIRECTION_INPUT,
    output = c.PW_DIRECTION_OUTPUT,
};

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

pub const Permission = extern struct {
    id: Id, // TODO global, or local Id?
    permissions: u32,

    pub fn fromPw(ptr: [*]const c.pw_permission, len: usize) []const Permission {
        const perms: [*]const Permission = @ptrCast(ptr);
        return perms[0..len];
    }
};

/// Not yet implemented
pub const DataLoop = void;
/// Not yet implemented
pub const DataSystem = void;
/// Not yet implemented
pub const Log = void;
/// Not yet implemented
pub const LoopControl = void;
/// Not yet implemented
pub const LoopUtils = void;
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
    _ = &std.testing.refAllDecls(MainLoop);
    _ = &std.testing.refAllDecls(Loop);
    _ = &std.testing.refAllDecls(Context);
    _ = &std.testing.refAllDecls(Core);
    _ = &std.testing.refAllDecls(Registry);
    _ = &std.testing.refAllDecls(Link);
    _ = &std.testing.refAllDecls(Port);
    _ = &std.testing.refAllDecls(Client);
    _ = &std.testing.refAllDecls(Device);
    _ = &std.testing.refAllDecls(Node);
    _ = &std.testing.refAllDecls(Properties);
    _ = &std.testing.refAllDecls(SPA);
    _ = &std.testing.refAllDecls(Stream);
    _ = &std.testing.refAllDecls(Permission);
    //_ = &std.testing.refAllDecls(DataLoop);
    //_ = &std.testing.refAllDecls(DataSystem);
    //_ = &std.testing.refAllDecls(Factory);
    //_ = &std.testing.refAllDecls(Log);
    //_ = &std.testing.refAllDecls(LoopControl);
    //_ = &std.testing.refAllDecls(LoopUtils);
    //_ = &std.testing.refAllDecls(Metadata);
    //_ = &std.testing.refAllDecls(Module);
    //_ = &std.testing.refAllDecls(Profiler);
    //_ = &std.testing.refAllDecls(SecurityContext);
    //_ = &std.testing.refAllDecls(System);
    //_ = &std.testing.refAllDecls(ThreadUtils);
}
