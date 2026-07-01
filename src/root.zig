//! By convention, root.zig is the root source file when making a package.
const std = @import("std");

pub fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "basic add functionality" {
    try std.testing.expect(add(3, 7) == 10);
}

test {
    _ = @import("win32.zig");
    _ = @import("updater.zig");
}
