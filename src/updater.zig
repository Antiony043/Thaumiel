const std = @import("std");

pub const SemVer = struct {
    major: u16,
    minor: u16,
    patch: u16,

    pub fn parse(str: []const u8) !SemVer {
        const v = if (str.len > 0 and str[0] == 'v') str[1..] else str;
        var parts = std.mem.splitScalar(u8, v, '.');
        const major_str = parts.next() orelse return error.InvalidVersion;
        const minor_str = parts.next() orelse return error.InvalidVersion;
        const patch_str = parts.next() orelse return error.InvalidVersion;
        return SemVer{
            .major = try std.fmt.parseUnsigned(u16, major_str, 10),
            .minor = try std.fmt.parseUnsigned(u16, minor_str, 10),
            .patch = try std.fmt.parseUnsigned(u16, patch_str, 10),
        };
    }

    pub fn format(self: SemVer, writer: *std.Io.Writer) std.Io.Writer.Error!void {
        try writer.print("v{d}.{d}.{d}", .{ self.major, self.minor, self.patch });
    }
};

pub const CURRENT_VERSION = SemVer{ .major = 0, .minor = 1, .patch = 0 };

test "semver parse" {
    const v = try SemVer.parse("v0.1.0");
    try std.testing.expectEqual(@as(u16, 0), v.major);
    try std.testing.expectEqual(@as(u16, 1), v.minor);
    try std.testing.expectEqual(@as(u16, 0), v.patch);
}

test "semver parse without v prefix" {
    const v = try SemVer.parse("1.2.3");
    try std.testing.expectEqual(@as(u16, 1), v.major);
}
