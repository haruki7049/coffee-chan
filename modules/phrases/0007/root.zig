//! Musical phrase 0007 composition and loader functions.

const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("utils");

/// Declaration of phrase notes and structure parsed from phrase.zon.
pub const phrase_data: utils.phrase.Phrase(f64, utils.scale.Scale) = @import("./phrase.zon");

/// Converts phrase 0007 notes into Note events.
pub fn toEvents(
    comptime T: type,
    comptime S: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
) ![]utils.note.Note(T) {
    return try phrase_data.toEvents(S, allocator, bpm, sample_rate);
}

/// Converts phrase 0007 notes transposed by semitones into Note events.
pub fn toEventsTransposed(
    comptime T: type,
    comptime S: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    semitones: isize,
) ![]utils.note.Note(T) {
    return try phrase_data.toEventsTransposed(S, allocator, bpm, sample_rate, semitones);
}

/// Synthesizes and loads phrase 0007 notes onto a sequencer track.
pub fn load(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    target_track: *utils.sequencer.Track(T),
    start_position: utils.sequencer.Position,
    volume: T,
) !void {
    try loadTransposed(T, G, S, seq, target_track, start_position, volume, 0);
}

/// Synthesizes and loads phrase 0007 notes transposed by semitones onto a sequencer track.
pub fn loadTransposed(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    target_track: *utils.sequencer.Track(T),
    start_position: utils.sequencer.Position,
    volume: T,
    semitones: isize,
) !void {
    const events = try toEventsTransposed(T, S, seq.allocator, seq.bpm, seq.sample_rate, semitones);
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

/// Synthesizes and loads phrase 0007 notes across an instrument's strings.
pub fn loadInstrument(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    instrument: utils.sequencer.Instrument(T),
    start_position: utils.sequencer.Position,
    volume: T,
) !void {
    try loadInstrumentTransposed(T, G, S, seq, instrument, start_position, volume, 0);
}

/// Synthesizes and loads phrase 0007 notes transposed by semitones across an instrument's strings.
pub fn loadInstrumentTransposed(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    instrument: utils.sequencer.Instrument(T),
    start_position: utils.sequencer.Position,
    volume: T,
    semitones: isize,
) !void {
    try phrase_data.loadInstrumentTransposed(G, S, seq, instrument, start_position, volume, semitones);
}

/// Renders phrase 0007 into a standalone lightmix.Wave(T).
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

test "gen phrase 0007" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;
    var wave = try gen(f64, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}

test "loadInstrument phrase 0007 across strings" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;

    var seq = utils.sequencer.Sequencer(f64).init(allocator, 120, .{}, 44100, 2);
    defer seq.deinit();

    var guitar = try seq.createInstrument("AcousticGuitar", 6);
    defer guitar.deinit(allocator);

    try loadInstrument(f64, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{}, 1.0);

    var wave = try seq.render();
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
