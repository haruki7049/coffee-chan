const std = @import("std");

pub const VinylNoise = @import("./vinyl_noise.zig");

test {
    std.testing.refAllDecls(@This());
}
