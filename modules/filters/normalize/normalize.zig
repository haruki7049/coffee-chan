//! Peak amplitude normalization DSP filter for audio waveforms.
//!
//! DSP Architecture:
//! Scans the target sample buffer across all channels to find the maximum peak absolute amplitude
//! `max_volume`. If valid and non-silent, computes gain scalar `volume = limit / max_volume` and
//! uniformly scales all audio samples in-place. This maximizes dynamic range and headroom while
//! preventing clipping distortions.

const std = @import("std");
const lightmix = @import("lightmix");

/// Error set for peak normalization filter operations.
pub const Error = error{
    EmptyWave,
    SilentWave,
    InvalidLimit,
};

/// Scales sample amplitudes in-place so peak absolute amplitude equals `limit`.
pub fn inner(comptime T: type, target: *lightmix.Wave(T), limit: T) Error!void {
    if (limit <= 0.0 or std.math.isNan(limit)) return error.InvalidLimit;
    if (target.samples.len == 0) return error.EmptyWave;

    var max_volume: T = 0.0;
    for (target.samples) |sample| {
        if (@abs(sample) > max_volume)
            max_volume = @abs(sample);
    }

    if (max_volume == 0.0) return error.SilentWave;

    const volume: T = limit / max_volume;
    const mutable_samples = @constCast(target.samples);
    for (mutable_samples) |*sample| {
        sample.* *= volume;
    }
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

test "normalize filter with silent buffer returns error.SilentWave" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 6);
    @memset(samples, 0.0);

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try std.testing.expectError(error.SilentWave, inner(f64, &wave, 1.0));
}

test "normalize filter with empty buffer returns error.EmptyWave" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 0);

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try std.testing.expectError(error.EmptyWave, inner(f64, &wave, 1.0));
}

test "normalize filter with invalid limit returns error.InvalidLimit" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 2);
    samples[0] = 0.5;
    samples[1] = 0.5;

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try std.testing.expectError(error.InvalidLimit, inner(f64, &wave, 0.0));
    try std.testing.expectError(error.InvalidLimit, inner(f64, &wave, -0.5));
}

test "normalize filter scales multi-channel stereo wave to limit" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4);
    samples[0] = 0.2; // L0
    samples[1] = -0.4; // R0 (peak = 0.4)
    samples[2] = 0.1; // L1
    samples[3] = 0.0; // R1

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try inner(f64, &wave, 0.8);

    // Peak 0.4 is scaled to 0.8 (multiplied by 2.0)
    try std.testing.expectApproxEqAbs(@as(f64, 0.4), wave.samples[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, -0.8), wave.samples[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.2), wave.samples[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), wave.samples[3], 1e-6);
}
