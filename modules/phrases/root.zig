const std = @import("std");

pub const PhraseData = @import("./phrase_data.zig").PhraseData;
pub const _0000 = @import("./0000/root.zig");
pub const _0001 = @import("./0001/root.zig");
pub const _0002 = @import("./0002/root.zig");

test {
    std.testing.refAllDecls(@This());
    _ = @import("./phrase_data.zig");
}
