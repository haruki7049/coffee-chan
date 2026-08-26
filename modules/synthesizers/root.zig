const std = @import("std");

pub const sine = @import("./sine/root.zig");
pub const whitenoise = @import("./whitenoise/root.zig");
pub const karplus_strong = @import("./karplus-strong/root.zig");

test {
    std.testing.refAllDecls(@This());
}
