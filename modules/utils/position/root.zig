const std = @import("std");

pub const Position = @import("./position.zig");

test {
    std.testing.refAllDecls(@This());
}
