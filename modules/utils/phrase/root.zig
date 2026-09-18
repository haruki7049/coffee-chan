const std = @import("std");

pub const Phrase = @import("phrase.zig").Phrase;

test {
    std.testing.refAllDecls(@This());
    _ = @import("phrase.zig");
}
