const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Scale = utils.scale.Scale;
const Sine = synthesizers.sine.Sine;
const Splitter = utils.splitter.Splitter;
const spb = utils.tempo.spb;

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
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

test "gen phrase 0000" {
    const allocator = std.testing.allocator;
    var wave = try gen(f64, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
