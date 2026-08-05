const std = @import("std");
const lightmix = @import("lightmix");

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    frequency: T,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) !lightmix.Wave(T) {
    const samples = try array(T, allocator, frequency, sample_rate, channels, length, volume);

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
) ![]T {
    const radians_per_sec: T = frequency * 2.0 * std.math.pi;
    var samples = try allocator.alloc(T, length * channels);

    for (0..samples.len / channels) |i| {
        const t: T = @as(T, @floatFromInt(i)) / @as(T, @floatFromInt(sample_rate));
        const value: T = @sin(radians_per_sec * t) * volume;

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
    const expected: []const T = &.{
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
    };
    const actual = try array(T, allocator, 440.0, 44100.0, 1, 10, 1.0);
    defer allocator.free(actual);

    try std.testing.expectEqual(expected.len, actual.len);
    try std.testing.expectEqualSlices(T, expected, actual);
}

test "gen function" {
    const allocator = std.testing.allocator;

    const T = f64;
    const expected: []const T = &.{
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
        0.0,
    };
    const actual: lightmix.Wave(T) = try gen(T, allocator, 440.0, 44100.0, 1, 10, 1.0);
    defer actual.deinit();

    try std.testing.expectEqual(expected.len, actual.samples.len);
    try std.testing.expectEqualSlices(T, expected, actual.samples);
}
