const std = @import("std");

pub const Splitter = @import("./splitter.zig");

test {
    std.testing.refAllDecls(@This());
}
