const std = @import("std");

const Self = @This();

numerator: usize = 4,
denominator: usize = 4,

test {
    std.testing.refAllDecls(@This());
}
