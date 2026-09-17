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

test "normalize filter" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4);
    samples[0] = 0.1;
    samples[1] = -0.5;
    samples[2] = 0.25;
    samples[3] = -0.4;

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 1,
    };
    defer wave.deinit();

    try inner(f64, &wave, 1.0);

    try std.testing.expectApproxEqAbs(@as(f64, 0.2), wave.samples[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, -1.0), wave.samples[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), wave.samples[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, -0.8), wave.samples[3], 1e-6);
}
