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

test "decay filter" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4);
    samples[0] = 1.0;
    samples[1] = 1.0;
    samples[2] = 1.0;
    samples[3] = 1.0;

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 1,
    };
    defer wave.deinit();

    try inner(f64, &wave);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), wave.samples[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), wave.samples[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), wave.samples[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), wave.samples[3], 1e-6);
}
