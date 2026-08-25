const std = @import("std");
const lightmix = @import("lightmix");

const Self = @This();
var prng = std.Random.DefaultPrng.init(0);
const random = Self.prng.random();

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    frequency: T,
    feedback: T,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) !lightmix.Wave(T) {
    const samples: []T = try array(T, allocator, frequency, feedback, sample_rate, channels, length, volume);

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
    feedback: T,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) ![]T {
    var samples: []T = try allocator.alloc(T, length);

    const period_length: usize = @intFromFloat(@as(T, @floatFromInt(sample_rate)) / frequency);
    var buffer: []T = try allocator.alloc(T, period_length);
    defer allocator.free(buffer);

    // Initial burst (Noise)
    for (buffer) |*sample| {
        sample.* = random.float(T) * 2.0 - 1.0;
    }

    // Synthesis loop
    for (0..samples.len) |i| {
        const buffer_index: usize = i % period_length;
        const next_index: usize = (i + 1) % period_length;

        // Averaging filter (Low-pass) and feedback
        const v: T = (buffer[buffer_index] + buffer[next_index]) * 0.5 * feedback;
        buffer[buffer_index] = v;

        // For each channels...
        for (0..channels) |j| {
            const sample: T = v * volume;
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
    const actual = try array(T, allocator, 440.0, 0.995, 44100.0, 1, 10, 1.0);
    defer allocator.free(actual);

    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqualSlices(T, expected, actual);
}
