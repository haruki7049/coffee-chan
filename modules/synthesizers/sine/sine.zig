const std = @import("std");
const lightmix = @import("lightmix");

pub fn Options(comptime T: type) type {
    _ = T;
    return struct {};
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
    _ = options;
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
        0.06264832417874369,
        0.1250505236945281,
        0.18696144082725336,
        0.2481378479437379,
        0.30833940305910035,
        0.36732959406137883,
        0.42487666788983847,
        0.4807545410165317,
        0.5347436876541296,
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
        0.06264832417874369,
        0.1250505236945281,
        0.18696144082725336,
        0.2481378479437379,
        0.30833940305910035,
        0.36732959406137883,
        0.42487666788983847,
        0.4807545410165317,
        0.5347436876541296,
    };
    const actual: lightmix.Wave(T) = try gen(T, allocator, 440.0, 44100.0, 1, 10, 1.0, .{});
    defer actual.deinit();

    try std.testing.expectEqual(expected.len, actual.samples.len);
    try std.testing.expectEqualSlices(T, expected, actual.samples);
}

test "gen function supports multi-channel stereo" {
    const allocator = std.testing.allocator;
    const channels: u16 = 2;
    const length: usize = 12;
    var wave = try gen(f64, allocator, 440.0, 44100, channels, length, 0.7, .{});
    defer wave.deinit();

    try std.testing.expectEqual(channels, wave.channels);
    try std.testing.expectEqual(length * channels, wave.samples.len);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    for (0..length) |i| {
        try std.testing.expectEqual(wave.samples[i * channels], wave.samples[i * channels + 1]);
    }
}
