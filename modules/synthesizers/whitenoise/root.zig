const std = @import("std");

pub const WhiteNoise = @import("./whitenoise.zig");

test {
    std.testing.refAllDecls(@This());
}
