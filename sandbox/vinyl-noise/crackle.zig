const std = @import("std");
const lightmix = @import("lightmix");
const synthesizers = @import("synthesizers");

const T = f64;
const VinylNoise = synthesizers.vinyl_noise.VinylNoise;

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const FREQUENCY: T = 0.0;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = SAMPLE_RATE * 3;
    const VOLUME: T = 0.8;

    const vinyl_noise: lightmix.Wave(T) = try VinylNoise.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME, .{});
    return vinyl_noise;
}
