const std = @import("std");

pub const cache = @import("./cache/root.zig");
pub const DrumBank = @import("./drum-bank.zig").DrumBank;
pub const PhraseBank = @import("./phrase-bank.zig").PhraseBank;

test {
    std.testing.refAllDecls(@This());
    _ = @import("./cache/root.zig");
    _ = @import("./drum-bank.zig");
    _ = @import("./phrase-bank.zig");
}
