const std = @import("std");
const lightmix = @import("lightmix");

const Self = @This();
var prng = std.Random.DefaultPrng.init(0);
const random = Self.prng.random();

pub fn Options(comptime T: type) type {
    return struct {
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

test {
    std.testing.refAllDecls(@This());
}
