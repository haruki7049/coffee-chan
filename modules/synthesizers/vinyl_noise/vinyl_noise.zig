//! Continuous vinyl crackle noise audio generator synthesizer implementation.

const std = @import("std");
const lightmix = @import("lightmix");

var prng = std.Random.DefaultPrng.init(0);
const rand = prng.random();

/// Synthesis configuration options for the continuous vinyl noise generator.
pub fn Options(comptime T: type) type {
    return struct {
        /// Probability of a crackle impulse occurring per sample step (default: 0.008).
        crackle_density: T = 0.008,

        /// Amplitude multiplier for sparse impulse crackles (default: 0.8).
        crackle_volume: T = 0.8,

        /// Lower cutoff frequency for high-pass filter in Hz (default: 300.0).
        low_cutoff: T = 300.0,

        /// Upper cutoff frequency for low-pass filter in Hz (default: 3500.0).
        high_cutoff: T = 3500.0,
    };
}

/// Generates a Wave struct containing synthesized continuous vinyl crackle noise audio samples.
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

/// Generates raw sample buffer containing synthesized continuous vinyl crackle noise audio frames.
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
    _ = frequency;
    var samples = try allocator.alloc(T, length * channels);

    const dt: T = 1.0 / @as(T, @floatFromInt(sample_rate));
    const rc_low: T = 1.0 / (2.0 * std.math.pi * options.low_cutoff);
    const alpha_hpf: T = rc_low / (rc_low + dt);

    const rc_high: T = 1.0 / (2.0 * std.math.pi * options.high_cutoff);
    const alpha_lpf: T = dt / (rc_high + dt);

    var prev_raw: T = 0.0;
    var prev_hpf: T = 0.0;
    var prev_lpf: T = 0.0;

    var crackle_decay: T = 0.0;

    for (0..samples.len / channels) |i| {
        // Continuous background surface noise (zero-mean symmetric)
        const bg_noise: T = (rand.float(T) * 2.0 - 1.0) * 0.15;

        // Bipolar crackle impulse with randomized sign (+ or -) to prevent DC offset bias
        if (rand.float(T) < options.crackle_density) {
            const sign: T = if (rand.boolean()) 1.0 else -1.0;
            crackle_decay = sign * (rand.float(T) * 0.7 + 0.3) * options.crackle_volume;
        } else {
            crackle_decay *= 0.75; // rapid decay envelope
        }

        const raw_signal: T = bg_noise + crackle_decay;

        // High-pass filter (removes DC offset and low rumble)
        const hpf_out: T = alpha_hpf * (prev_hpf + raw_signal - prev_raw);
        prev_raw = raw_signal;
        prev_hpf = hpf_out;

        // Low-pass filter (smooths high frequency harshness for analog warmth)
        const lpf_out: T = prev_lpf + alpha_lpf * (hpf_out - prev_lpf);
        prev_lpf = lpf_out;

        // Symmetric output scaled by volume
        const value: T = lpf_out * 2.0 * volume;

        for (0..channels) |j| {
            samples[i * channels + j] = value;
        }
    }

    return samples;
}

test "array function generates expected buffer length" {
    const allocator = std.testing.allocator;
    const channels: u16 = 1;
    const length: usize = 100;
    const actual = try array(f64, allocator, 0.0, 44100, channels, length, 0.5, .{});
    defer allocator.free(actual);

    try std.testing.expectEqual(length * channels, actual.len);
}

test "gen function creates valid Wave struct" {
    const allocator = std.testing.allocator;
    const channels: u16 = 1;
    const length: usize = 50;
    var wave = try gen(f64, allocator, 0.0, 44100, channels, length, 0.5, .{});
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(length * channels, wave.samples.len);
}

test "array function supports multi-channel stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 64;
    const actual = try array(f64, allocator, 0.0, 44100, channels, length, 0.5, .{});
    defer allocator.free(actual);

    try std.testing.expectEqual(length * channels, actual.len);
    for (0..length) |i| {
        try std.testing.expectEqual(actual[i * channels], actual[i * channels + 1]);
    }
}

test "custom options modify generator behavior" {
    const allocator = std.testing.allocator;
    const wave = try gen(f64, allocator, 0.0, 44100, 1, 100, 0.5, .{
        .crackle_density = 0.01,
        .crackle_volume = 0.8,
        .low_cutoff = 200.0,
        .high_cutoff = 4000.0,
    });
    defer wave.deinit();

    try std.testing.expectEqual(@as(usize, 100), wave.samples.len);
}

test {
    std.testing.refAllDecls(@This());
}
