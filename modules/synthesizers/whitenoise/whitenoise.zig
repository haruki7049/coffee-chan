const std = @import("std");
const lightmix = @import("lightmix");

var prng = std.Random.DefaultPrng.init(0);
const rand = prng.random();

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) !lightmix.Wave(T) {
    const samples = try array(T, allocator, sample_rate, channels, length, volume);

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
    sample_rate: u32,
    channels: u16,
    length: usize,
    volume: T,
) ![]T {
    var samples: []T = try allocator.alloc(T, length);
    for (0..samples.len) |i| {
        // Random value between -0.5 and +0.5
        const v: T = (rand.float(T) * 2.0 - 1.0) * 0.5;
        samples[i] = v * volume;
    }

    return lightmix.Wave(T){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = sample_rate,
        .channels = channels,
    };
}
