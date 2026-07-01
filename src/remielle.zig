const std = @import("std");

pub fn exePath(gpa: std.mem.Allocator, dir: []const u8, name: []const u8) ![]const u8 {
    return try std.fmt.allocPrint(gpa, "{s}/zig-out/bin/{s}", .{ dir, name });
}

test "exePath produces correct path" {
    const path = try exePath(std.testing.allocator, "remielle", "remielle-dpsv.exe");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("remielle/zig-out/bin/remielle-dpsv.exe", path);
}

test "exePath with trailing slash" {
    const path = try exePath(std.testing.allocator, "remielle/", "remielle-gamesv.exe");
    defer std.testing.allocator.free(path);
    try std.testing.expectEqualStrings("remielle//zig-out/bin/remielle-gamesv.exe", path);
}
