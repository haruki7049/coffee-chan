const std = @import("std");

pub const cache = @import("./cache/root.zig");
pub const note = @import("./note/root.zig");
pub const phrase = @import("./phrase/root.zig");
pub const position = @import("./position/root.zig");
pub const scale = @import("./scale/root.zig");
pub const sequencer = @import("./sequencer/root.zig");
pub const tempo = @import("./tempo/root.zig");
pub const time_signature = @import("./time-signature/root.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("./cache/root.zig");
    _ = @import("./note/root.zig");
    _ = @import("./phrase/root.zig");
    _ = @import("./position/root.zig");
    _ = @import("./scale/root.zig");
    _ = @import("./sequencer/root.zig");
    _ = @import("./tempo/root.zig");
    _ = @import("./time-signature/root.zig");
}
