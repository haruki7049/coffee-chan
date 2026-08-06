const std = @import("std");
const lightmix = @import("lightmix");

pub const Error = std.mem.Allocator.Error;

pub fn inner(comptime T: type, target: *lightmix.Wave(T)) Error!void {
    const allocator = target.allocator;
    const sample_rate = target.sample_rate;
    const channels = target.channels;
    var samples = try allocator.alloc(T, target.samples.len);

    // Process each sample, applying a decay factor
    for (target.samples, 0..target.samples.len) |sample, i| {
        // Calculate how far from the end we are
        const remaining_samples = target.samples.len - i;

        // Decay factor: 1.0 at start, 0.0 at end
        const decay_factor = @as(T, @floatFromInt(remaining_samples)) /
            @as(T, @floatFromInt(target.samples.len));

        // Apply the decay to the sample
        const decayed_sample = sample * decay_factor;
        samples[i] = decayed_sample;
    }

    // Free original samples on target variable
    target.allocator.free(target.samples);

    target.allocator = allocator;
    target.samples = samples;
    target.sample_rate = sample_rate;
    target.channels = channels;
}
