const std = @import("std");

pub const TemplateCache = @import("template_cache.zig").inner;
pub const WaveCache = @import("wave_cache.zig").inner;

test {
    std.testing.refAllDecls(@This());
    _ = @import("template_cache.zig");
    _ = @import("wave_cache.zig");
}
