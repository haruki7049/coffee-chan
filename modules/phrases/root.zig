const std = @import("std");

pub const _0000 = @import("./0000/root.zig");
pub const _0001 = @import("./0001/root.zig");
pub const _0002 = @import("./0002/root.zig");
pub const _0003 = @import("./0003/root.zig");
pub const _0004 = @import("./0004/root.zig");
pub const _0005 = @import("./0005/root.zig");
pub const _0006 = @import("./0006/root.zig");

test {
    std.testing.refAllDecls(@This());
}
