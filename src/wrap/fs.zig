//! Pipewire checks for the presence of dynamic libraries and loads some config at runtime. This
//! file stubs out the relevant file system accesses so the dynamic libraries don't need to be
//! present, and the config files don't need to be shipped with the executable.
//! user installed config files.

const std = @import("std");
const log = std.log.scoped(.wrap_dlfcn);
const fmtFlags = @import("format.zig").fmtFlags;
const dlfcn = @import("dlfcn.zig");

/// The path pipewire looks for client config at.
const client_config_path = "pipewire-0.3/confdata/client.conf";

/// The client config data.
const client_conf: [:0]const u8 = @embedFile("client.conf");

/// The current client config file descriptor, or -1 if not open.
var maybe_client_config_fd: ?std.c.fd_t = null;

extern "c" fn fstatat(dirfd: i32, path: [*:0]const u8, buf: [*]const u8, flag: u32) c_int;
extern "c" fn fstat(dirfd: i32, buf: [*]const u8) c_int;
extern "c" fn stat(noalias path: [*:0]const u8, noalias buf: [*]const u8) c_int;

// The `stat` definition used by the Linux kernel.
pub const Stat = extern struct {
    dev: u64,
    ino: u64,
    nlink: u64,

    mode: u32,
    uid: std.os.linux.uid_t,
    gid: std.os.linux.gid_t,
    __pad0: u32,
    rdev: u64,
    size: i64,
    blksize: i64,
    blocks: i64,

    atim: std.os.linux.timespec,
    mtim: std.os.linux.timespec,
    ctim: std.os.linux.timespec,
    __unused: [3]i64,

    pub fn atime(self: @This()) std.os.linux.timespec {
        return self.atim;
    }

    pub fn mtime(self: @This()) std.os.linux.timespec {
        return self.mtim;
    }

    pub fn ctime(self: @This()) std.os.linux.timespec {
        return self.ctim;
    }
};

/// If we're stating a shared library from out table, fake the result.
pub export fn __wrap_stat(noalias pathname_c: [*:0]const u8, noalias statbuf: *Stat) callconv(.c) c_int {
    const pathname = std.mem.span(pathname_c);
    const result: c_int, const strategy = b: {
        if (dlfcn.libs.get(pathname) != null) {
            //statbuf.* = @splat(0);
            statbuf.* = std.mem.zeroInit(Stat, .{ .mode = std.c.S.IFREG });
            //@as(*u32, @ptrCast(@alignCast(statbuf[28..][0..4].ptr))).* = std.c.S.IFREG;
            break :b .{ 0, "faked" };
        } else {
            break :b .{ stat(pathname_c, @ptrCast(statbuf)), "real" };
        }
    };
    log.debug("stat(\"{s}\", {*}) -> {} (statbuf.* == {any}) ({s})", .{
        std.mem.span(pathname_c), statbuf, result, statbuf.*, strategy,
    });
    return 0; //res;
}

/// If we're calling access on a config file, fake the result.
pub export fn __wrap_access(path_c: [*:0]const u8, mode: c_int) callconv(.c) c_int {
    const path = std.mem.span(path_c);
    const result, const strategy = b: {
        if (mode == std.c.R_OK and std.mem.eql(u8, path, client_config_path)) {
            break :b .{ 0, "faked" };
        } else {
            break :b .{ std.c.access(path, @intCast(mode)), "real" };
        }
    };
    log.debug("access(\"{f}\", {}) -> {} ({s})", .{
        std.zig.fmtString(path), mode, result, strategy,
    });
    return result;
}

/// If we're calling open on a config file, fake the result. Called by `va.c`.
pub export fn __nova_wrap_open(
    path_c: [*:0]const u8,
    flags: std.c.O,
    mode: std.c.mode_t,
) callconv(.c) std.c.fd_t {
    const path = std.mem.span(path_c);
    const result, const strategy = b: {
        if (std.meta.eql(flags, .{ .CLOEXEC = true, .ACCMODE = .RDONLY }) and std.mem.eql(u8, path, client_config_path)) {
            if (maybe_client_config_fd != null) @panic("client_config_path already open");
            const fd = std.c.open("/dev/null", flags, mode);
            maybe_client_config_fd = fd;
            break :b .{ fd, "faked" };
        } else {
            break :b .{ std.c.open(path_c, flags, mode), "real" };
        }
    };
    log.debug("open(\"{f}\", {f}, {}) -> {} ({s})", .{
        std.zig.fmtString(path), fmtFlags(flags), mode, result, strategy,
    });
    return result;
}

/// From `va.c`.
pub extern fn __wrap_open(path_c: [*:0]const u8, flags: std.c.O, ...) callconv(.c) std.c.fd_t;

/// glibc aliases open to check the variadic args.
pub const __wrap_open_2 = __wrap_open;
/// glibc aliases open to check the variadic args.
pub const __wrap___open_alias = __wrap_open;

/// If we're closing a config file, reset `maybe_client_config_fd`.
pub export fn __wrap_close(fd: std.c.fd_t) callconv(.c) c_int {
    if (maybe_client_config_fd == fd) maybe_client_config_fd = null;
    const result = std.c.close(fd);
    log.debug("close({}) -> {}", .{ fd, result });
    return result;
}

/// If we're fstating a config file, fake the output and result.
pub export fn __wrap_fstat(fd: std.c.fd_t, buf: *[256]u8) callconv(.c) c_int {
    //const result: c_int, const strategy = b: {
    //    if (fd == maybe_client_config_fd) {
    //        buf.* = @splat(0);
    //        //buf.* = std.mem.zeroInit(std.os.linux.Statx, .{
    //        //    .ino = 0,
    //        //    .mode = std.c.S.IFREG,
    //        //    .nlink = 0,
    //        //    .uid = std.math.maxInt(std.c.uid_t),
    //        //    .gid = std.math.maxInt(std.c.gid_t),
    //        //    .size = client_conf.len,
    //        //    .blksize = 0,
    //        //    .blocks = 0,
    //        //    .atime = std.mem.zeroes(std.os.linux.statx_timestamp),
    //        //    .mtime = std.mem.zeroes(std.os.linux.statx_timestamp),
    //        //    .ctime = std.mem.zeroes(std.os.linux.statx_timestamp),
    //        //});
    //        break :b .{ 0, "real" };
    //    } else {
    //        break :b .{ @intCast(std.os.linux.statx(
    //            fd,
    //            "",
    //            std.os.linux.AT.EMPTY_PATH,
    //            @bitCast(std.os.linux.STATX{ .TYPE = true, .SIZE = true }),
    //            buf,
    //        )), "xreal" };
    //    }
    //};
    const result = fstat(fd, buf);
    log.debug("fstat({}, {*}) -> {} (buf.* = {any}) ({s})", .{ fd, buf, result, buf.*, "mocked" });
    return result;
}

/// If we're mmaping a config file, fake the output and result.
pub export fn __wrap_mmap(
    addr: ?*anyopaque,
    length: usize,
    prot: std.os.linux.PROT,
    flags: std.c.MAP,
    fd: std.c.fd_t,
    offset: std.c.off_t,
) callconv(.c) *anyopaque {
    const result: *anyopaque, const strategy = b: {
        if (fd == maybe_client_config_fd) {
            // Check the arguments
            if (addr != null) {
                std.debug.panic("__wrap_mmap: {s}: addr {*} != null", .{
                    client_config_path,
                    addr,
                });
            }
            if (length != client_conf.len) {
                std.debug.panic("__wrap_mmap: {s}: length {} != {}", .{
                    client_config_path,
                    length,
                    client_conf.len,
                });
            }
            if (prot.READ) {
                std.debug.panic("__wrap_mmap: {s}: unexpected prot: {}", .{
                    client_config_path,
                    prot,
                });
            }
            if (!std.meta.eql(flags, .{ .TYPE = .PRIVATE })) {
                std.debug.panic("__wrap_mmap: {s}: unexpected flags: {}", .{
                    client_config_path,
                    flags,
                });
            }
            if (offset != 0) {
                std.debug.panic("__wrap_mmap: {s}: unexpected offset: {}", .{
                    client_config_path,
                    offset,
                });
            }

            // Fake the result
            break :b .{ @ptrCast(@constCast(client_conf.ptr)), "faked" };
        } else {
            break :b .{
                std.c.mmap(@alignCast(addr), length, prot, flags, fd, offset),
                "real",
            };
        }
    };
    log.debug("mmap({*}, {}, {}, {f}, {}, {}) -> {*} ({s})", .{
        addr,
        length,
        prot,
        fmtFlags(flags),
        fd,
        offset,
        result,
        strategy,
    });
    return result;
}

/// If we're unmapping the config file, do nothing since we didn't really map it.
pub export fn __wrap_munmap(addr: *const anyopaque, length: usize) callconv(.c) c_int {
    const result, const strategy = b: {
        if (@intFromPtr(addr) == @intFromPtr(client_conf.ptr)) {
            if (length != client_conf.len) {
                std.debug.panic("__wrap_munmap: {s}: length {} != {}", .{
                    client_config_path,
                    length,
                    client_conf.len,
                });
            }
            break :b .{ 0, "faked" };
        } else {
            break :b .{ std.c.munmap(@alignCast(addr), length), "real" };
        }
    };
    log.debug("munmap({*}, {}) -> {} ({s})", .{ addr, length, result, strategy });
    return result;
}
