const std = @import("std");
const lightmix = @import("lightmix");
const synthesizers = @import("synthesizers");

const T = f64;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const FREQUENCY: T = 110.0; // Low A (Bass range)
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = SAMPLE_RATE * 2;
    const VOLUME: T = 1.0;

    const wave: lightmix.Wave(T) = try KarplusStrong.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME, .{
        .feedback = 0.996,
        .filter_weight = 0.95, // Adjust high-frequency damping
        .excitation_lpf_passes = 24, // Apply low-pass filter passes to initial excitation noise for deep bass pluck
    });
    return wave;
}
