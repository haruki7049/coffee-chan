const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Scale = utils.scale.Scale;
const Sine = synthesizers.sine.Sine;
const Sequencer = utils.sequencer.Sequencer;
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
    const base_length: usize = spb(bpm, sample_rate) * 4;

    var long = try Sine.gen(T, allocator, freq, sample_rate, channels, base_length, volume);
    defer long.deinit();
    try filters.decay(T, &long);

    var short = try Sine.gen(T, allocator, freq, sample_rate, channels, base_length / 2, volume);
    defer short.deinit();
    try filters.decay(T, &short);

    var seq = Sequencer(T).init(allocator, bpm, .{}, sample_rate, channels);
    defer seq.deinit();

    const track = try seq.createTrack("Phrase 0000");

    // 1 bars pattern
    try seq.addWave(track, long, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, short, .{ .bar = 0, .beat = 2.0 });
    try seq.addWave(track, short, .{ .bar = 0, .beat = 3.0 });

    return try seq.render();
}

test "gen phrase 0000" {
    const allocator = std.testing.allocator;
    var wave = try gen(f64, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
