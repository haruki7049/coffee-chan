const std = @import("std");
const lightmix = @import("lightmix");
const synthesizers = @import("synthesizers");

const T = f64;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const FREQUENCY: T = 440.0;
    const FEEDBACK: T = 0.995;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = SAMPLE_RATE * 2;
    const VOLUME: T = 1.0;

    const karplus_strong_440: lightmix.Wave(T) = try KarplusStrong.gen(T, allocator, FREQUENCY, FEEDBACK, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME);
    return karplus_strong_440;
}
