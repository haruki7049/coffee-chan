//! Extended Karplus-Strong physical modeling plucked-string synthesizer.
//!
//! Architectural & Physical Modeling Overview:
//! 1. Delay Line & Period Buffer: Allocates a delay ring buffer of length `P = sample_rate / frequency`
//!    representing string length and fundamental pitch.
//! 2. Excitation Noise Burst: Fills the ring buffer with uniform white noise samples `[-1.0, 1.0]`
//!    simulating the physical pluck or strike.
//! 3. Pick Filter (`excitation_lpf_passes`): Applies preliminary low-pass filtering passes over
//!    the noise burst to smooth high transients and enhance fundamental bass resonance.
//! 4. Recirculating Feedback Loop: Iterates over requested output frames, blending adjacent delay
//!    samples using a weighted 2-point averaging filter (`v = (buf[i] * w + buf[i+1] * (1 - w)) * feedback`)
//!    and writing back into the ring buffer to simulate acoustic string vibration decay.

const std = @import("std");
const lightmix = @import("lightmix");

var prng = std.Random.DefaultPrng.init(0);

/// Resets the internal pseudo-random number generator to its initial deterministic seed.
pub fn reset() void {
    prng = std.Random.DefaultPrng.init(0);
}

/// Synthesis configuration options for the Extended Karplus-Strong algorithm.
pub fn Options(comptime T: type) type {
    return struct {
        /// Feedback attenuation factor per buffer loop (default: 0.995). Controls long-tail sustain.
        feedback: T = 0.995,

        /// Loop filter weight (0.0 < filter_weight < 1.0).
        /// Default is 0.5 (standard 2-point averaging filter).
        /// Adjusting filter_weight controls high-frequency decay rate and pitch fine-tuning.
        filter_weight: T = 0.5,

        /// Low-pass filter passes applied to initial excitation noise (Pick Filter).
        /// Higher values smooth excitation noise, suppressing high frequencies and enhancing low-frequency fundamental.
        excitation_lpf_passes: usize = 0,
    };
}

/// Generates a Wave struct containing synthesized plucked string audio samples.
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
    const samples: []T = try array(T, allocator, frequency, sample_rate, channels, length, volume, options);

    return lightmix.Wave(T){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = sample_rate,
        .channels = channels,
    };
}

/// Generates raw sample buffer containing synthesized plucked string audio frames.
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
    const random = prng.random();
    var samples: []T = try allocator.alloc(T, length * channels);

    const period_length: usize = @intFromFloat(@as(T, @floatFromInt(sample_rate)) / frequency);
    var buffer: []T = try allocator.alloc(T, period_length);
    defer allocator.free(buffer);

    // Initial burst (White noise)
    for (buffer) |*sample| {
        sample.* = random.float(T) * 2.0 - 1.0;
    }

    // Apply Low-pass filtering to initial excitation noise (Pick filter for bass enhancement)
    for (0..options.excitation_lpf_passes) |_| {
        var prev: T = buffer[buffer.len - 1];
        for (buffer) |*sample| {
            const curr = sample.*;
            sample.* = (curr + prev) * 0.5;
            prev = curr;
        }
    }

    // Synthesis loop
    for (0..samples.len / channels) |i| {
        const buffer_index: usize = i % period_length;
        const next_index: usize = (i + 1) % period_length;

        // Weighted low-pass filter and feedback (Extended Karplus-Strong)
        const filter_weight = options.filter_weight;
        const v: T = (buffer[buffer_index] * filter_weight + buffer[next_index] * (1.0 - filter_weight)) * options.feedback;
        buffer[buffer_index] = v;

        const sample: T = v * volume;
        // For each channel...
        for (0..channels) |j| {
            samples[i * channels + j] = sample;
        }
    }

    return samples;
}

test "array function" {
    const allocator = std.testing.allocator;

    const T = f64;
    const expected: []const T = &.{
        -0.22077647834640665,
        -0.08849504244870379,
        -0.4845307552832268,
        -0.5755437024387423,
        -0.5712785892534946,
        -0.33633635120856237,
        0.24348814047517972,
        0.06464248289378464,
        -0.4683670866623902,
        -0.610015522700841,
    };
    const actual = try array(T, allocator, 440.0, 44100.0, 1, 10, 1.0, .{});
    defer allocator.free(actual);

    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqualSlices(T, expected, actual);
}

test "gen function returning wave with options and stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 20;
    var wave = try gen(f64, allocator, 440.0, 44100, channels, length, 0.8, .{
        .feedback = 0.99,
        .filter_weight = 0.6,
        .excitation_lpf_passes = 1,
    });
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(length * channels, wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    for (0..length) |i| {
        try std.testing.expectEqual(wave.samples[i * channels], wave.samples[i * channels + 1]);
    }
}

test "reset produces bitwise deterministic output" {
    const allocator = std.testing.allocator;
    reset();
    const run1 = try array(f64, allocator, 440.0, 44100, 2, 200, 0.5, .{});
    defer allocator.free(run1);

    reset();
    const run2 = try array(f64, allocator, 440.0, 44100, 2, 200, 0.5, .{});
    defer allocator.free(run2);

    try std.testing.expectEqualSlices(f64, run1, run2);
}

test {
    std.testing.refAllDecls(@This());
}
