const std = @import("std");

pub const TimeSignature = @import("./time-signature.zig");

test {
    std.testing.refAllDecls(@This());
}
