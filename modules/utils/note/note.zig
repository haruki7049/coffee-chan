//! Musical note representation with position, frequency, duration length, and volume.

const std = @import("std");
const sequencer = @import("../sequencer/root.zig");

/// Returns a Note type parameterised by numeric floating point type T.
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
