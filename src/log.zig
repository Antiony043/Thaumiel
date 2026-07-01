const std = @import("std");
const win32 = @import("win32.zig");

const Io = std.Io;

pub var file_logger: ?*Logger = null;
pub var global_io: ?std.Io = null;

pub fn logFn(
    comptime message_level: std.log.Level,
    comptime scope: @TypeOf(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_str = comptime message_level.asText();
    const scope_str = @tagName(scope);

    if (file_logger) |logger| {
        if (global_io) |io| {
            if (logger.active) {
                const prefix = comptime std.fmt.comptimePrint("[{s}] ({s}) ", .{ level_str, scope_str });
                const buf = std.fmt.allocPrint(logger.allocator, prefix ++ format ++ "\n", args) catch return;
                defer logger.allocator.free(buf);
                if (logger.file) |f| {
                    _ = std.Io.File.writeStreamingAll(f, io, buf) catch {};
                }
            }
        }
    }
}

pub const Logger = struct {
    allocator: std.mem.Allocator,
    file: ?Io.File,
    active: bool = false,
    counter: u64 = 0,

    pub fn init(io: std.Io, allocator: std.mem.Allocator) !Logger {
        const logs_dir = win32.getLogsDir(allocator) catch |err| {
            if (err == error.EnvironmentVariableNotFound) return Logger{ .allocator = allocator, .file = null };
            return err;
        };
        defer allocator.free(logs_dir);
        try win32.ensureDir(io, logs_dir);

        // sweep orphaned .tmp files from a previous crash
        if (std.Io.Dir.openDirAbsolute(io, logs_dir, .{ .iterate = true })) |logs_d| {
            defer logs_d.close(io);
            var iter = std.Io.Dir.iterate(logs_d);
            while (iter.next(io) catch null) |entry| {
                if (entry.kind == .file and std.mem.endsWith(u8, entry.name, ".tmp")) {
                    logs_d.deleteFile(io, entry.name) catch {};
                }
            }
        } else |_| {}

        const ts = std.Io.Clock.real.now(io);
        const filename = try std.fmt.allocPrint(allocator, "thaumiel-{d}.log", .{ts.toMicroseconds()});
        defer allocator.free(filename);

        const filepath = try std.fs.path.join(allocator, &.{ logs_dir, filename });
        defer allocator.free(filepath);

        const dir = Io.Dir.cwd();
        const file = try dir.createFile(io, filepath, .{});
        return Logger{ .allocator = allocator, .file = file, .active = true };
    }

    pub fn write(self: *Logger, io: std.Io, comptime fmt: []const u8, args: anytype) !void {
        const f = self.file orelse return;
        if (!self.active) return;
        self.counter += 1;
        const buf = try std.fmt.allocPrint(self.allocator, "[{d}] " ++ fmt ++ "\n", .{self.counter} ++ args);
        defer self.allocator.free(buf);
        try f.writeStreamingAll(io, buf);
    }

    pub fn deinit(self: *Logger, io: std.Io) void {
        if (self.active) {
            if (self.file) |f| f.close(io);
        }
    }
};

test "logger defaults inactive" {
    const logger = Logger{ .allocator = std.testing.allocator, .file = null, .active = false };
    try std.testing.expectEqual(@as(u64, 0), logger.counter);
    try std.testing.expect(!logger.active);
}

test "logger counter increments" {
    var logger = Logger{ .allocator = std.testing.allocator, .file = null, .active = true };
    logger.counter += 1;
    try std.testing.expectEqual(@as(u64, 1), logger.counter);
    logger.counter += 1;
    try std.testing.expectEqual(@as(u64, 2), logger.counter);
}
