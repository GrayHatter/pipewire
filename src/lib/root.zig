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
            .device => .{ .device = .{ .ptr = @ptrCast(bind_proxy) } },
            .node => .{ .node = .{ .ptr = @ptrCast(bind_proxy) } },
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
            param: ?*const fn (*T, ?*anyopaque, c_int, u32, u32, u32, [*c]const c.struct_spa_pod) void = null,
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
            param: ?*const fn (*T, i32, u32, u32, u32, [*]const SimplePlugin.POD) void = null,
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
                    seq,
                    id,
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

    pub fn enumParams(node: Node, seq: i32, id: SimplePlugin.Param.Id, start: u32, max: u32, filter: []const SimplePlugin.POD) !void {
        if (filter.len != 0) return error.FilterNotImplemented;
        const res = c.pw_node_enum_params(node.ptr, seq, @intFromEnum(id), start, max, null);
        if (res < 0) {
            std.debug.print("enum res {} : {} {} {} {}\n", .{ res, seq, id, start, max });
            return error.EnumerationFailed;
        }
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

        const Type = enum(u32) {
            id = 3,
            int = 4,
            object = 15,
            _,
        };

        pub const Builder = struct {
            bytes: []align(8) u8,
            len: usize = 0,

            pub const Flags = packed struct(u32) {
                _: u32 = 0,

                pub const none: Flags = .{};
            };

            pub const Object = struct {
                builder: *Builder,
                body: []align(8) u8,

                pub fn append(obj: *Object, prop: u32, flags: Flags, comptime kind: POD.Type, val: anytype) !void {
                    var buffer: [256]u8 = undefined; // TODO size array correctly
                    const padding: u32 = 0;
                    var new: []u8 = &.{};
                    switch (kind) {
                        .id => {
                            std.mem.writeInt(u32, buffer[0..][0..4], prop, .native);
                            std.mem.writeInt(u32, buffer[4..][0..4], @bitCast(flags), .native);
                            std.mem.writeInt(u32, buffer[8..][0..4], 4, .native); // size
                            std.mem.writeInt(u32, buffer[12..][0..4], @intFromEnum(kind), .native);
                            std.mem.writeInt(u32, buffer[16..][0..4], @bitCast(val), .native);
                            std.mem.writeInt(u32, buffer[20..][0..4], padding, .native);
                            new = buffer[0..24];
                        },

                        .int => {
                            std.mem.writeInt(u32, buffer[0..][0..4], prop, .native);
                            std.mem.writeInt(u32, buffer[4..][0..4], @bitCast(flags), .native);
                            std.mem.writeInt(u32, buffer[8..][0..4], 4, .native); // size
                            std.mem.writeInt(u32, buffer[12..][0..4], @intFromEnum(kind), .native);
                            std.mem.writeInt(u32, buffer[16..][0..4], @bitCast(val), .native);
                            std.mem.writeInt(u32, buffer[20..][0..4], padding, .native);
                            new = buffer[0..24];
                        },
                        .object => unreachable,
                        _ => unreachable,
                    }

                    obj.body = try obj.builder.append(obj.body, new);
                }

                pub fn toPwPod(obj: *Object) *c.spa_pod {
                    return @ptrCast(obj.body);
                }

                pub fn toPwPodFrame(obj: *Object) *c.spa_pod_frame {
                    return @ptrCast(obj.body);
                }
            };

            pub fn init(buffer: []align(8) u8) Builder {
                return .{ .bytes = buffer };
            }

            pub fn pushObject(build: *Builder, obj_type: u32, obj_id: Param.Id) !Object {
                std.debug.assert(build.len % 8 == 0);
                var body: []align(8) u8 = @alignCast(build.bytes[build.len..]);
                const empty_size = 8;
                std.mem.writeInt(u32, body[0..][0..4], empty_size, .native);
                std.mem.writeInt(u32, body[4..][0..4], @intFromEnum(POD.Type.object), .native);
                std.mem.writeInt(u32, body[8..][0..4], obj_type, .native);
                std.mem.writeInt(u32, body[12..][0..4], @intFromEnum(obj_id), .native);
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
            var c_pod_buffer: [2048]u8 = undefined;
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
            var zig_frame = try builder.pushObject(c.SPA_TYPE_OBJECT_Format, .enum_format);
            try zig_frame.append(c.SPA_FORMAT_mediaType, .none, .id, c.SPA_MEDIA_TYPE_audio);
            try zig_frame.append(c.SPA_FORMAT_mediaSubtype, .none, .id, c.SPA_MEDIA_SUBTYPE_raw);
            try zig_frame.append(c.SPA_FORMAT_AUDIO_format, .none, .id, c.SPA_AUDIO_FORMAT_F32);
            try zig_frame.append(c.SPA_FORMAT_AUDIO_rate, .none, .int, @as(u32, 48000));
            try zig_frame.append(c.SPA_FORMAT_AUDIO_channels, .none, .int, @as(u32, 2));

            try std.testing.expectEqual(&zig_pod_buffer, @as([*]u8, @ptrCast(zig_frame.toPwPod())));
            try std.testing.expectEqual(c.spa_pod{ .size = 128, .type = 15 }, zig_frame.toPwPod().*);

            try std.testing.expectEqualSlices(u8, &c_pod_buffer, &zig_pod_buffer);
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
