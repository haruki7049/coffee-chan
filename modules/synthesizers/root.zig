//! Sound generators.
//!
//! Every synthesizer is a file struct with a `gen` function that returns a `lightmix.Wave(T)`.
//! Synthesizers fall into two families, distinguished by whether they have a pitch:
//!
//! - Pitched (`sine`, `rhodes`, `karplus_strong`, `wood_bass`):
//!   `gen(T, allocator, frequency, sample_rate, channels, length, volume, options)`.
//!   This is the shape that phrase rendering (`phrases.Bind`) expects of its generator.
//! - Unpitched (`whitenoise`, `vinyl_noise`):
//!   `gen(T, allocator, sample_rate, channels, length, volume)`, plus a trailing `options`
//!   argument when the synthesizer has options (`vinyl_noise`). There is no `frequency`.
//!
//! A new synthesizer follows the shape of its family.

const std = @import("std");

pub const sine = @import("./sine/root.zig");
pub const whitenoise = @import("./whitenoise/root.zig");
pub const karplus_strong = @import("./karplus-strong/root.zig");
pub const rhodes = @import("./rhodes/root.zig");
pub const wood_bass = @import("./wood-bass/root.zig");
pub const vinyl_noise = @import("./vinyl-noise/root.zig");

test {
    std.testing.refAllDecls(@This());
}
