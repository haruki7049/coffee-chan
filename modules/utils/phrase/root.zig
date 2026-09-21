const std = @import("std");

pub const Phrase = @import("phrase.zig").Phrase;
pub const Bind = @import("phrase.zig").Bind;

test {
    std.testing.refAllDecls(@This());
    _ = @import("phrase.zig");
}
