const std = @import("std");

pub const cache = @import("./cache/root.zig");
pub const phrase = @import("./phrase/root.zig");
pub const sequencer = @import("./sequencer/root.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("./cache/root.zig");
    _ = @import("./phrase/root.zig");
    _ = @import("./sequencer/root.zig");
}
