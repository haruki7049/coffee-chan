const std = @import("std");

pub const Scale = @import("./scale.zig");

test {
    std.testing.refAllDecls(@This());
}
