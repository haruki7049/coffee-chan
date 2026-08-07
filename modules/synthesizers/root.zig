const std = @import("std");

pub const sine = @import("./sine/root.zig");
pub const whitenoise = @import("./whitenoise/root.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
