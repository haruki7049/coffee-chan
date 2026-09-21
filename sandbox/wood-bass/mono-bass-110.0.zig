const std = @import("std");
const lightmix = @import("lightmix");
const synthesizers = @import("synthesizers");

const T = f64;
const WoodBass = synthesizers.wood_bass.WoodBass;

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const FREQUENCY: T = 110.0;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 1;
    const LENGTH: usize = SAMPLE_RATE * 2;
    const VOLUME: T = 1.0;

    const wood_bass_110: lightmix.Wave(T) = try WoodBass.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME, .{});
    return wood_bass_110;
}
