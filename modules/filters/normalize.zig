const std = @import("std");
const lightmix = @import("lightmix");

const Error = std.mem.Allocator.Error;

pub fn inner(comptime T: type, target: *lightmix.Wave(T), limit: T) Error!void {
    const allocator = target.allocator;
    const sample_rate = target.sample_rate;
    const channels = target.channels;
    var samples = try allocator.alloc(T, target.samples.len);

    var max_volume: T = 0.0;
    for (target.samples) |sample| {
        if (@abs(sample) > max_volume)
            max_volume = @abs(sample);
    }

    for (target.samples, 0..) |sample, i| {
        const volume: T = limit / max_volume;

        const new_sample: T = sample * volume;
        samples[i] = new_sample;
    }

    // Free original samples on target variable
    target.allocator.free(target.samples);

    target.allocator = allocator;
    target.samples = samples;
    target.sample_rate = sample_rate;
    target.channels = channels;
}
