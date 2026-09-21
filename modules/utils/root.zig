const std = @import("std");

pub const cache = @import("./cache/root.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("./cache/root.zig");
}
