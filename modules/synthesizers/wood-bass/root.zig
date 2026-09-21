const std = @import("std");

pub const WoodBass = @import("./wood_bass.zig");

test {
    std.testing.refAllDecls(@This());
}
