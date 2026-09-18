const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("utils");

const phrase_data: utils.phrase.Phrase(f64, utils.scale.Scale) = @import("./phrase.zon");

pub fn gen(
    comptime T: type,
    comptime SoundGen: type,
    comptime ScaleGen: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
    const events = try phrase_data.toEvents(ScaleGen, allocator, bpm, sample_rate);
    defer allocator.free(events);

    var seq = utils.sequencer.Sequencer(T).init(allocator, bpm, .{}, sample_rate, channels);
    defer seq.deinit();

    const track = try seq.createTrack(phrase_data.name);
    try seq.addEvents(track, SoundGen, events, volume);

    return try seq.render();
}

test "gen phrase 0000" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;
    var wave = try gen(f64, synthesizers.sine.Sine, utils.scale.Scale, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
