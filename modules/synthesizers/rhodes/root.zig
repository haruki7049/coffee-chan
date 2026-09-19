const std = @import("std");

pub const Rhodes = @import("./rhodes.zig");

test {
    std.testing.refAllDecls(@This());
}
