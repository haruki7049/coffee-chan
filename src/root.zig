const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const sine = @import("sine");
const scale = @import("scale");
const splitter = @import("splitter");
const tempo = @import("tempo");

const T = f64;
const Scale = scale.Scale;
const Sine = sine.Sine;
const Splitter = splitter.Splitter;
const spb = tempo.spb;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const BPM: usize = 60;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var result: lightmix.Wave(T) = try four_sine_tone(allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    try filters.normalize(T, &result, 1.0);
    return result;
}

fn four_sine_tone(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const freq: T = Scale.gen(.{ .code = .c, .octave = 4 });
    var s = try Sine.gen(T, allocator, freq, sample_rate, channels, spb(bpm, sample_rate), volume);
    defer s.deinit();
    try filters.decay(T, &s);

    return try Splitter.gen(T, allocator, spb(bpm, sample_rate) * 4, &.{ s, s, s, s }, sample_rate, channels);
}
