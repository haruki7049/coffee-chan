const std = @import("std");

pub const Note = @import("note.zig").Note;

test {
    std.testing.refAllDecls(@This());
    _ = @import("note.zig");
}
