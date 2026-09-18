const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Scale = utils.scale.Scale;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;
const spb = utils.tempo.spb;

const Sequencer = utils.sequencer.Sequencer;

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
    const frequency: T = Scale.gen(.{ .code = .a, .octave = 2 });
    const length: usize = spb(bpm, sample_rate) * 4;

    var long: lightmix.Wave(T) = try KarplusStrong.gen(T, allocator, frequency, sample_rate, channels, length, volume, .{
        .feedback = 0.995,
        .filter_weight = 0.8, // Adjust high-frequency damping
        .excitation_lpf_passes = 24, // Apply low-pass filter passes to initial excitation noise for deep bass pluck
    });
    defer long.deinit();

    var short: lightmix.Wave(T) = try KarplusStrong.gen(T, allocator, frequency, sample_rate, channels, length / 2, volume, .{
        .feedback = 0.995,
        .filter_weight = 0.8, // Adjust high-frequency damping
        .excitation_lpf_passes = 24, // Apply low-pass filter passes to initial excitation noise for deep bass pluck
    });
    defer short.deinit();

    var seq = Sequencer(T).init(allocator, bpm, .{}, sample_rate, channels);
    defer seq.deinit();

    const track = try seq.createTrack("Phrase 0002");
    try seq.addWave(track, long, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, short, .{ .bar = 0, .beat = 2.0 });
    try seq.addWave(track, short, .{ .bar = 0, .beat = 3.0 });

    return try seq.render();
}

test "gen phrase 0002" {
    const allocator = std.testing.allocator;
    var wave = try gen(f64, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
