const std = @import("std");

pub const VinylNoise = @import("./vinyl-noise.zig");

test {
    std.testing.refAllDecls(@This());
}
