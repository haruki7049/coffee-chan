const std = @import("std");

pub const normalize = @import("./normalize.zig").inner;

test {
    std.testing.refAllDecls(@This());
}
