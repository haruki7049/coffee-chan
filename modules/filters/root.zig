const std = @import("std");

pub const decay = @import("./decay/root.zig").decay;
pub const normalize = @import("./normalize/root.zig").normalize;

test {
    std.testing.refAllDecls(@This());
    _ = @import("./decay/root.zig");
    _ = @import("./normalize/root.zig");
}
