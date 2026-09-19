//! Musical phrase 0001 composition and loader functions.

const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("utils");

/// Declaration of phrase notes and structure parsed from phrase.zon.
pub const phrase_data: utils.phrase.Phrase(f64, utils.scale.Scale) = @import("./phrase.zon");

/// Converts phrase 0001 notes into Note events.
pub fn toEvents(
    comptime T: type,
    comptime S: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
) ![]utils.note.Note(T) {
    return try phrase_data.toEvents(S, allocator, bpm, sample_rate);
}

/// Synthesizes and loads phrase 0001 notes onto a sequencer track.
pub fn load(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    target_track: *utils.sequencer.Track(T),
    start_position: utils.sequencer.Position,
    volume: T,
) !void {
    const events = try toEvents(T, S, seq.allocator, seq.bpm, seq.sample_rate);
    defer seq.allocator.free(events);

    for (events) |event| {
        var pos = event.position;
        pos.bar += start_position.bar;
        pos.beat += start_position.beat;

        const note_wave = try G.gen(
            T,
            seq.allocator,
            event.freq,
            seq.sample_rate,
            seq.channels,
            event.length,
            volume * event.volume,
            .{},
        );
        try seq.add(target_track, note_wave, pos);
    }
}

/// Renders phrase 0001 into a standalone lightmix.Wave(T).
pub fn gen(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
    var seq = utils.sequencer.Sequencer(T).init(allocator, bpm, .{}, sample_rate, channels);
    defer seq.deinit();

    const track = try seq.createTrack(phrase_data.name);
    try load(T, G, S, &seq, track, .{}, volume);

    return try seq.render();
}

test "gen phrase 0001" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;
    var wave = try gen(f64, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
