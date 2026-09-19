//! White noise audio generator synthesizer implementation.

const std = @import("std");
const lightmix = @import("lightmix");

var prng = std.Random.DefaultPrng.init(0);

/// Resets the internal pseudo-random number generator to its initial deterministic seed.
pub fn reset() void {
    prng = std.Random.DefaultPrng.init(0);
}

/// Generates a Wave struct containing pseudo-random white noise audio samples.
pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) !lightmix.Wave(T) {
    const samples: []const T = try array(T, allocator, channels, length, volume);

    return lightmix.Wave(T){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = sample_rate,
        .channels = channels,
    };
}

/// Generates raw sample buffer containing pseudo-random white noise audio frames.
pub fn array(
    comptime T: type,
    allocator: std.mem.Allocator,
    channels: u16,
    length: usize,
    volume: T,
) ![]T {
    const rand = prng.random();
    var samples: []T = try allocator.alloc(T, length * channels);
    for (0..samples.len / channels) |i| {
        // Random value between -0.5 and +0.5
        const original_value: T = (rand.float(T) * 2.0 - 1.0) * 0.5;
        // Volume adjusted value
        const adjusted_value: T = original_value * volume;

        for (0..channels) |j| {
            samples[i * channels + j] = adjusted_value;
        }
    }

    return samples;
}

test "The generated []T is the expected one" {
    const T: type = f64;
    const allocator: std.mem.Allocator = std.testing.allocator;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = 10;
    const VOLUME: T = 1.0;

    const actual: []const T = try array(T, allocator, CHANNELS, LENGTH, VOLUME);
    defer allocator.free(actual);
    const expected: []const T = &.{
        -0.13492553583950168,
        -0.08696037204633417,
        -0.001979369108142004,
        -0.48498621409108095,
        -0.09344966775690133,
        -0.4806996681762591,
        0.14267318454956324,
        0.10203851442046663,
        -0.03707119492922578,
        -0.4336494951837292,
    };

    try std.testing.expectEqual(expected.len, actual.len);
    for (0..expected.len) |i| {
        try std.testing.expectApproxEqAbs(expected[i], actual[i], 0.000001);
    }
}

test "The generated lightmix.Wave(T) is the expected one" {
    const T: type = f64;
    const allocator: std.mem.Allocator = std.testing.allocator;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = 10;
    const VOLUME: T = 1.0;

    const actual: lightmix.Wave(T) = try gen(T, allocator, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME);
    defer actual.deinit();
    const expected: lightmix.Wave(T) = lightmix.Wave(T){
        .allocator = allocator,
        .channels = CHANNELS,
        .sample_rate = SAMPLE_RATE,
        .samples = &.{
            -0.17943143215379953,
            -0.3983269981888001,
            -0.3815114936823649,
            -0.4215756019158081,
            -0.4079451727047251,
            -0.044189485646385196,
            0.19150725190424556,
            -0.43542372046830463,
            -0.028778570507844936,
            -0.2154862289570349,
        },
    };

    try std.testing.expectEqual(expected.channels, actual.channels);
    try std.testing.expectEqual(expected.sample_rate, actual.sample_rate);
    try std.testing.expectEqual(expected.samples.len, actual.samples.len);

    for (0..expected.samples.len) |i| {
        try std.testing.expectApproxEqAbs(expected.samples[i], actual.samples[i], 0.000001);
    }
}

test "array function supports multi-channel stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 8;
    const actual = try array(f64, allocator, channels, length, 1.0);
    defer allocator.free(actual);

    try std.testing.expectEqual(length * channels, actual.len);
    for (0..length) |i| {
        try std.testing.expectEqual(actual[i * channels], actual[i * channels + 1]);
        try std.testing.expect(actual[i * channels] >= -0.5 and actual[i * channels] <= 0.5);
    }
}

test "gen function supports multi-channel stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 16;
    var wave = try gen(f64, allocator, 44100, channels, length, 0.8);
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(length * channels, wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
}

test "reset produces bitwise deterministic output" {
    const allocator = std.testing.allocator;
    reset();
    const run1 = try array(f64, allocator, 2, 200, 0.5);
    defer allocator.free(run1);

    reset();
    const run2 = try array(f64, allocator, 2, 200, 0.5);
    defer allocator.free(run2);

    try std.testing.expectEqualSlices(f64, run1, run2);
}

test {
    std.testing.refAllDecls(@This());
}
