const std = @import("std");

pub const decay = @import("./decay.zig").inner;
pub const normalize = @import("./normalize.zig").inner;

test {
    std.testing.refAllDeclsRecursive(@This());
}
