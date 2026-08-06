const std = @import("std");
const lightmix = @import("lightmix");
const sine = @import("sine");

const T = f64;
const Sine = sine.Sine;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const FREQUENCY: T = 440.0;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = SAMPLE_RATE * 2;
    const VOLUME: T = 1.0;

    const sine_440: lightmix.Wave(T) = try Sine.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME);
    return sine_440;
}
