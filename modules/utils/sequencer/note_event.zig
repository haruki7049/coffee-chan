const std = @import("std");
const Position = @import("position.zig");

pub fn NoteEvent(comptime T: type) type {
    return struct {
        position: Position = .{},
        freq: T,
        length: usize,
        volume: T = 1.0,
    };
}

test {
    std.testing.refAllDecls(@This());
}
