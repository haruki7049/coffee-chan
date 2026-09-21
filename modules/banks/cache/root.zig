const std = @import("std");

pub const TemplateCache = @import("template-cache.zig").inner;
pub const WaveCache = @import("wave-cache.zig").inner;

test {
    std.testing.refAllDecls(@This());
    _ = @import("template-cache.zig");
    _ = @import("wave-cache.zig");
}
