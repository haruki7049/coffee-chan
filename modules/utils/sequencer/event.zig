const std = @import("std");
const lightmix = @import("lightmix");
const Position = @import("position.zig");

pub fn inner(comptime T: type) type {
    return struct {
        wave: lightmix.Wave(T),
        position: Position,
    };
}

test {
    std.testing.refAllDecls(@This());
}
