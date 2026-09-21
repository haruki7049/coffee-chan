//! FM Pizzicato Wood Bass synthesizer implementation.
//!
//! Synthesizes acoustic upright and wood bass tones by combining Frequency Modulation (FM)
//! for initial pluck transients with low-pass filtering and exponential decay envelopes.

const std = @import("std");
const lightmix = @import("lightmix");

/// Synthesis configuration options for the Wood Bass generator.
pub fn Options(comptime T: type) type {
    return struct {
        /// Primary amplitude exponential decay rate for pizzicato bass sound tail (default: 4.0).
        decay_rate: T = 4.0,

        /// FM modulator frequency ratio relative to carrier fundamental frequency (default: 1.0).
        modulator_ratio: T = 1.0,

        /// Initial FM modulation index (depth) for pluck transient (default: 1.5).
        modulator_index: T = 1.5,

        /// Exponential decay rate for the FM modulation index (default: 8.0).
        modulator_decay: T = 8.0,

        /// Cutoff frequency for single-pole low-pass filtering in Hz (default: 800.0).
        lpf_cutoff: T = 800.0,
    };
}

/// Generates a Wave struct containing synthesized Wood Bass audio samples.
pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    frequency: T,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
    options: Options(T),
) !lightmix.Wave(T) {
    const samples = try array(T, allocator, frequency, sample_rate, channels, length, volume, options);

    return lightmix.Wave(T){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = sample_rate,
        .channels = channels,
    };
}

/// Generates raw sample buffer containing synthesized Wood Bass audio frames.
pub fn array(
    comptime T: type,
    allocator: std.mem.Allocator,
    frequency: T,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
    options: Options(T),
) ![]T {
    var samples = try allocator.alloc(T, length * channels);

    const carrier_rad_per_sec: T = frequency * 2.0 * std.math.pi;
    const modulator_rad_per_sec: T = frequency * options.modulator_ratio * 2.0 * std.math.pi;
    const sample_rate_t: T = @as(T, @floatFromInt(sample_rate));
    const dt: T = 1.0 / sample_rate_t;

    const safe_cutoff: T = @max(options.lpf_cutoff, @as(T, 1.0));
    const lpf_alpha: T = std.math.exp(-2.0 * std.math.pi * safe_cutoff * dt);

    var lpf_state: T = 0.0;

    for (0..length) |i| {
        const t: T = @as(T, @floatFromInt(i)) / sample_rate_t;

        const env: T = std.math.exp(-options.decay_rate * t);
        const fm_idx: T = options.modulator_index * std.math.exp(-options.modulator_decay * t);

        const modulator: T = fm_idx * @sin(modulator_rad_per_sec * t);
        const raw_sample: T = @sin(carrier_rad_per_sec * t + modulator) * env * volume;

        lpf_state = lpf_state * lpf_alpha + raw_sample * (1.0 - lpf_alpha);

        for (0..channels) |j| {
            samples[i * channels + j] = lpf_state;
        }
    }

    return samples;
}

test {
    std.testing.refAllDecls(@This());
}

test "array function" {
    const allocator = std.testing.allocator;

    const T = f64;
    const actual = try array(T, allocator, 110.0, 44100, 1, 10, 1.0, .{});
    defer allocator.free(actual);

    try std.testing.expectEqual(@as(usize, 10), actual.len);
    // Initial sample starts near zero due to LPF initialization and sin(0) = 0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), actual[0], 1e-6);
}

test "gen function" {
    const allocator = std.testing.allocator;

    const T = f64;
    const wave = try gen(T, allocator, 110.0, 44100, 1, 100, 0.8, .{});
    defer wave.deinit();

    try std.testing.expectEqual(@as(usize, 100), wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 1), wave.channels);
}

test "gen function supports multi-channel stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 20;
    var wave = try gen(f64, allocator, 110.0, 44100, channels, length, 0.7, .{});
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(length * channels, wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    for (0..length) |i| {
        try std.testing.expectEqual(wave.samples[i * channels], wave.samples[i * channels + 1]);
    }
}

test "wood bass decay and custom options" {
    const allocator = std.testing.allocator;
    const T = f64;

    const length: usize = 44100; // 1 second
    const actual = try array(T, allocator, 110.0, 44100, 1, length, 1.0, .{
        .decay_rate = 6.0,
        .modulator_ratio = 1.0,
        .modulator_index = 2.0,
        .modulator_decay = 10.0,
        .lpf_cutoff = 500.0,
    });
    defer allocator.free(actual);

    // Peak amplitude early in the note should be substantially larger than tail amplitude
    var max_early: f64 = 0.0;
    for (actual[100..1000]) |sample| {
        if (@abs(sample) > max_early) max_early = @abs(sample);
    }

    var max_late: f64 = 0.0;
    for (actual[20000..30000]) |sample| {
        if (@abs(sample) > max_late) max_late = @abs(sample);
    }

    try std.testing.expect(max_early > max_late * 5.0);
}
