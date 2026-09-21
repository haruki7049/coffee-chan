const std = @import("std");

pub const decay = @import("./decay.zig").inner;

test {
    std.testing.refAllDecls(@This());
}
