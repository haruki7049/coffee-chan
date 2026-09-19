//! Rhodes Electric Piano synthesizer implementation.
//!
//! Architectural & Synthesis Overview:
//! Synthesizes electric piano sound combining fundamental sine wave with mild harmonic overtones
//! and an exponential decay envelope (`decay_rate: T = 3.0` by default).

const std = @import("std");
const lightmix = @import("lightmix");

/// Synthesis configuration options for the Rhodes electric piano generator.
pub fn Options(comptime T: type) type {
    return struct {
        /// Exponential decay factor for natural electric piano tail decay (default: 3.0).
        decay_rate: T = 3.0,
    };
}

/// Generates a Wave struct containing synthesized Rhodes electric piano audio samples.
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

/// Generates raw sample buffer containing synthesized Rhodes electric piano audio frames.
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
    const radians_per_sec: T = frequency * 2.0 * std.math.pi;
    var samples = try allocator.alloc(T, length * channels);

    for (0..samples.len / channels) |i| {
        const t: T = @as(T, @floatFromInt(i)) / @as(T, @floatFromInt(sample_rate));
        const env: T = std.math.exp(-options.decay_rate * t);

        const fundamental: T = @sin(radians_per_sec * t);
        const h2: T = @sin(radians_per_sec * 2.0 * t) * 0.4;
        const h3: T = @sin(radians_per_sec * 3.0 * t) * 0.2;
        const h4: T = @sin(radians_per_sec * 4.0 * t) * 0.1;
        const raw_signal: T = (fundamental + h2 + h3 + h4) / 1.7;

        const value: T = raw_signal * env * volume;

        for (0..channels) |j| {
            samples[i * channels + j] = value;
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
    const actual = try array(T, allocator, 440.0, 44100.0, 1, 10, 1.0, .{});
    defer allocator.free(actual);

    try std.testing.expectEqual(@as(usize, 10), actual.len);
    // Initial sample at t=0 should be 0.0 since sin(0) = 0 for all harmonics
    try std.testing.expectEqual(@as(T, 0.0), actual[0]);

    // Check decay envelope behavior: amplitude should decay over time
    const t_mid = try array(T, allocator, 440.0, 44100.0, 1, 44100, 1.0, .{ .decay_rate = 3.0 });
    defer allocator.free(t_mid);

    const first_peak = @abs(t_mid[25]); // Near first peak
    const later_peak = @abs(t_mid[44100 / 2 + 25]); // Half second later
    try std.testing.expect(later_peak < first_peak);
}

test "gen function returning wave with options and stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 20;
    var wave = try gen(f64, allocator, 440.0, 44100, channels, length, 0.8, .{ .decay_rate = 3.0 });
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(length * channels, wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    for (0..length) |i| {
        try std.testing.expectEqual(wave.samples[i * channels], wave.samples[i * channels + 1]);
    }
}
