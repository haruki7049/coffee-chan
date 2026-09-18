const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("utils");

pub const phrase_data: utils.phrase.Phrase(f64, utils.scale.Scale) = @import("./phrase.zon");

pub fn toEvents(
    comptime T: type,
    comptime S: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
) ![]utils.note.Note(T) {
    return try phrase_data.toEvents(S, allocator, bpm, sample_rate);
}

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

pub fn loadInstrument(
    comptime T: type,
    comptime G: type,
    comptime S: type,
    seq: *utils.sequencer.Sequencer(T),
    instrument: utils.sequencer.Instrument(T),
    start_position: utils.sequencer.Position,
    volume: T,
) !void {
    try phrase_data.loadInstrument(G, S, seq, instrument, start_position, volume);
}

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

test "gen phrase 0000" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;
    var wave = try gen(f64, synthesizers.sine.Sine, utils.scale.Scale, allocator, 60, 44100, 2, 1.0);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}

test "loadInstrument phrase 0000" {
    const synthesizers = @import("synthesizers");
    const allocator = std.testing.allocator;

    var seq = utils.sequencer.Sequencer(f64).init(allocator, 120, .{}, 44100, 2);
    defer seq.deinit();

    var inst = try seq.createInstrument("LeadSynth", 1);
    defer inst.deinit(allocator);

    try loadInstrument(f64, synthesizers.sine.Sine, utils.scale.Scale, &seq, inst, .{}, 1.0);

    var wave = try seq.render();
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
}
