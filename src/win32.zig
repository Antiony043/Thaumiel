const std = @import("std");

fn getEnvVar(allocator: std.mem.Allocator, key: []const u8) ![]const u8 {
    const environ: std.process.Environ = .{ .block = .{ .use_global = true } };
    return try std.process.Environ.getAlloc(environ, allocator, key);
}

pub fn getAppDataDir(allocator: std.mem.Allocator) ![]const u8 {
    const appdata = try getEnvVar(allocator, "APPDATA");
    defer allocator.free(appdata);
    return try std.fs.path.join(allocator, &.{ appdata, "Thaumiel" });
}

pub fn exeDir(io: std.Io, gpa: std.mem.Allocator) ![]const u8 {
    return try std.process.executableDirPathAlloc(io, gpa);
}

pub fn bundledDir(io: std.Io, gpa: std.mem.Allocator, name: []const u8) ![]const u8 {
    const cwd = std.Io.Dir.cwd();

    if (exeDir(io, gpa)) |dir| {
        defer gpa.free(dir);
        // exe_dir/name (e.g. zig-out/bin/remielle)
        const bundled = try std.fs.path.join(gpa, &.{ dir, name });
        if (cwd.access(io, bundled, .{})) {
            return bundled;
        } else |_| {
            gpa.free(bundled);
        }
        // exe_dir/../../name (project root, for zig-out/bin/ exe)
        const up = try std.fs.path.join(gpa, &.{ dir, "..", "..", name });
        if (cwd.access(io, up, .{})) {
            return up;
        } else |_| {
            gpa.free(up);
        }
    } else |_| {}

    const fallback = try std.fs.path.join(gpa, &.{name});
    if (cwd.access(io, fallback, .{})) {
        return fallback;
    } else |_| {
        gpa.free(fallback);
        return error.FileNotFound;
    }
}

pub fn zigExe(io: std.Io, gpa: std.mem.Allocator) ![]const u8 {
    const cwd = std.Io.Dir.cwd();

    if (exeDir(io, gpa)) |dir| {
        defer gpa.free(dir);
        const bundled = try std.fs.path.join(gpa, &.{ dir, "zig", "zig.exe" });
        if (cwd.access(io, bundled, .{ .read = true })) {
            return bundled;
        } else |_| {
            gpa.free(bundled);
        }
        const up = try std.fs.path.join(gpa, &.{ dir, "..", "..", "zig", "zig.exe" });
        if (cwd.access(io, up, .{ .read = true })) {
            return up;
        } else |_| {
            gpa.free(up);
        }
    } else |_| {}

    return try gpa.dupe(u8, "zig");
}

pub fn ensureDir(io: std.Io, path: []const u8) !void {
    const dir = std.Io.Dir.cwd();
    dir.createDirPath(io, path) catch |err| switch (err) {
        error.PathAlreadyExists => {},
        else => return err,
    };
}

test "getAppDataDir returns Thaumiel subdirectory" {
    const dir = try getAppDataDir(std.testing.allocator);
    defer std.testing.allocator.free(dir);
    try std.testing.expect(std.mem.endsWith(u8, dir, "Thaumiel"));
}
