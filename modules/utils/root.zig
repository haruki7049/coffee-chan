const std = @import("std");

pub const scale = @import("./scale/root.zig");
pub const splitter = @import("./splitter/root.zig");
pub const tempo = @import("./tempo/root.zig");

test {
    std.testing.refAllDeclsRecursive(@This());
}
