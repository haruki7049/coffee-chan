const std = @import("std");

pub const Sine = @import("./sine.zig");

test {
    std.testing.refAllDecls(@This());
}
