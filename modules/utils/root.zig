const std = @import("std");

pub const cache = @import("./cache/root.zig");
pub const phrase = @import("./phrase/root.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("./cache/root.zig");
    _ = @import("./phrase/root.zig");
}
