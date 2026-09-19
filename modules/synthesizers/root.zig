const std = @import("std");

pub const sine = @import("./sine/root.zig");
pub const whitenoise = @import("./whitenoise/root.zig");
pub const karplus_strong = @import("./karplus-strong/root.zig");
pub const rhodes = @import("./rhodes/root.zig");
pub const wood_bass = @import("./wood_bass/root.zig");
pub const vinyl_noise = @import("./vinyl_noise/root.zig");

test {
    std.testing.refAllDecls(@This());
}
