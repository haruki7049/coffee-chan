const std = @import("std");
const lightmix = @import("lightmix");
const sine = @import("sine");

const T = f64;
const FREQUENCY: T = 440.0;
const SAMPLE_RATE: u32 = 44100;
const CHANNELS: u16 = 2;
const LENGTH: usize = SAMPLE_RATE * 2;
const VOLUME: T = 1.0;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const result: lightmix.Wave(T) = try sine.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME);
    return result;
}
