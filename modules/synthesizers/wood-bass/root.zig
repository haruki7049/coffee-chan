const std = @import("std");

pub const WoodBass = @import("./wood-bass.zig");

test {
    std.testing.refAllDecls(@This());
}
