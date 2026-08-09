const std = @import("std");

pub const _0000 = @import("./0000/root.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
