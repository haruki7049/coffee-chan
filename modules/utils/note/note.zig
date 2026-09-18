const std = @import("std");
const sequencer = @import("../sequencer/root.zig");

pub fn Note(comptime T: type) type {
    return struct {
        position: sequencer.Position = .{},
        freq: T,
        length: usize,
        volume: T = 1.0,
    };
}

test {
    std.testing.refAllDecls(@This());
}
