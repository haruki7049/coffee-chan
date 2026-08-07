const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const T = f64;
const Scale = utils.scale.Scale;
const Sine = synthesizers.sine.Sine;
const Splitter = utils.splitter.Splitter;
const spb = utils.tempo.spb;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const BPM: usize = 60;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var result: lightmix.Wave(T) = try sine_tones(allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    try filters.normalize(T, &result, 1.0);
    return result;
}

fn sine_tones(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const freq: T = Scale.gen(.{ .code = .c, .octave = 4 });

    const long_spb: usize = @intFromFloat(@as(
        f64,
        @as(f64, @floatFromInt(spb(bpm, sample_rate))) * 4,
    ));
    var long = try Sine.gen(T, allocator, freq, sample_rate, channels, long_spb, volume);
    defer long.deinit();
    try filters.decay(T, &long);

    var short = try Sine.gen(T, allocator, freq, sample_rate, channels, spb(bpm, sample_rate) / 2, volume);
    defer short.deinit();
    try filters.decay(T, &short);

    return try Splitter.gen(
        T,
        allocator,
        spb(bpm, sample_rate) * 16,
        &.{
            long,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            short,
            short,
            short,
            short,

            long,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            null,
            short,
            short,
            short,
            short,
        },
        sample_rate,
        channels,
    );
}
