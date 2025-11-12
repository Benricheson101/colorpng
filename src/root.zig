const std = @import("std");

pub const chunk = @import("chunk.zig");

pub const PNG_SIGNATURE = [_]u8{ 137, 80, 78, 71, 13, 10, 26, 10 };

test {
    _ = std.testing.refAllDeclsRecursive(@This());
}
