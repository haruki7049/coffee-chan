const std = @import("std");

pub const KarplusStrong = @import("./karplus-strong.zig");

test {
    std.testing.refAllDecls(@This());
}
