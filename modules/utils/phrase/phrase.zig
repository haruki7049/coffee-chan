//! Musical phrase structure, note container, and sequencer rendering loading functions.

const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("../root.zig");
const Note = utils.note.Note;

/// Returns a Phrase type parameterized by sample floating-point type T and scale note type N.
pub fn Phrase(comptime T: type, comptime N: type) type {
    return struct {
        const Self = @This();

        /// Raw note definition stored in musical phrase declarations.
        pub const RawNote = struct {
            bar: usize = 0,
            beat: f64 = 0.0,
            note: N,
            duration_beats: f64 = 1.0,
            volume: T = 1.0,
            string: usize = 0,
        };

        name: []const u8,
        notes: []const RawNote,

        /// Converts raw notes into frequency-resolved Note events.
        pub fn toEvents(
            self: Self,
            comptime S: type,
            allocator: std.mem.Allocator,
            bpm: usize,
            sample_rate: u32,
        ) ![]Note(T) {
            var events = try allocator.alloc(Note(T), self.notes.len);

            const spb_val: f64 = @floatFromInt(utils.tempo.spb(bpm, sample_rate));

            for (self.notes, 0..) |item, i| {
                events[i] = .{
                    .position = .{ .bar = item.bar, .beat = item.beat },
                    .freq = @floatCast(S.gen(item.note)),
                    .length = @intFromFloat(spb_val * item.duration_beats),
                    .volume = item.volume,
                };
            }

            return events;
        }

        /// Synthesizes and schedules phrase notes onto a multi-string instrument in the sequencer.
        pub fn loadInstrument(
            self: Self,
            comptime G: type,
            comptime S: type,
            seq: *utils.sequencer.Sequencer(T),
            instrument: utils.sequencer.Instrument(T),
            start_position: utils.sequencer.Position,
            volume: T,
        ) !void {
            const spb_val: f64 = @floatFromInt(utils.tempo.spb(seq.bpm, seq.sample_rate));

            for (self.notes) |item| {
                const pos = utils.sequencer.Position{
                    .bar = item.bar + start_position.bar,
                    .beat = item.beat + start_position.beat,
                };
                const freq = @as(T, @floatCast(S.gen(item.note)));
                const length: usize = @intFromFloat(spb_val * item.duration_beats);
                const note_wave = try G.gen(
                    T,
                    seq.allocator,
                    freq,
                    seq.sample_rate,
                    seq.channels,
                    length,
                    volume * item.volume,
                    .{},
                );
                const string_idx = if (instrument.stringCount() > 0) item.string % instrument.stringCount() else 0;
                try seq.addInstrument(instrument, string_idx, note_wave, pos);
            }
        }
    };
}

test "Phrase loadInstrument plays chords across instrument strings" {
    const allocator = std.testing.allocator;

    const DummySoundGen = struct {
        pub fn gen(
            comptime F: type,
            alloc: std.mem.Allocator,
            freq: F,
            sample_rate: u32,
            channels: u16,
            samples_len: usize,
            volume: F,
            options: anytype,
        ) !lightmix.Wave(F) {
            _ = freq;
            _ = options;
            const samples = try alloc.alloc(F, samples_len * channels);
            @memset(samples, volume);
            return lightmix.Wave(F){
                .allocator = alloc,
                .sample_rate = sample_rate,
                .channels = channels,
                .samples = samples,
            };
        }
    };

    const DummyNote = struct {
        code: enum { c, e, g },
        octave: usize,
    };

    const DummyScale = struct {
        pub fn gen(note: DummyNote) f64 {
            return switch (note.code) {
                .c => 261.63,
                .e => 329.63,
                .g => 392.00,
            };
        }
    };

    const phrase = Phrase(f64, DummyNote){
        .name = "ChordPhrase",
        .notes = &[_]Phrase(f64, DummyNote).RawNote{
            .{ .bar = 0, .beat = 0.0, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 2.0, .string = 0 },
            .{ .bar = 0, .beat = 0.0, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 2.0, .string = 1 },
            .{ .bar = 0, .beat = 0.0, .note = .{ .code = .g, .octave = 4 }, .duration_beats = 2.0, .string = 2 },
        },
    };

    var seq = utils.sequencer.Sequencer(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    var guitar = try seq.createInstrument("Guitar", 6);
    defer guitar.deinit(allocator);

    try phrase.loadInstrument(DummySoundGen, DummyScale, &seq, guitar, .{}, 1.0);

    var rendered = try seq.render();
    defer rendered.deinit();

    try std.testing.expect(rendered.samples.len > 0);
}

test "Phrase toEvents converts raw notes into sequenced events" {
    const allocator = std.testing.allocator;

    const DummyNote = struct {
        code: enum { c, e },
        octave: usize,
    };

    const DummyScale = struct {
        pub fn gen(note: DummyNote) f64 {
            return switch (note.code) {
                .c => 261.63,
                .e => 329.63,
            };
        }
    };

    const phrase = Phrase(f64, DummyNote){
        .name = "TestEvents",
        .notes = &[_]Phrase(f64, DummyNote).RawNote{
            .{ .bar = 1, .beat = 1.5, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 1.0, .volume = 0.8 },
            .{ .bar = 2, .beat = 0.0, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 0.5, .volume = 0.6 },
        },
    };

    // 60 BPM, 44100 Hz => spb = 44100
    const events = try phrase.toEvents(DummyScale, allocator, 60, 44100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 2), events.len);

    try std.testing.expectEqual(@as(usize, 1), events[0].position.bar);
    try std.testing.expectEqual(@as(f64, 1.5), events[0].position.beat);
    try std.testing.expectApproxEqAbs(@as(f64, 261.63), events[0].freq, 1e-2);
    try std.testing.expectEqual(@as(usize, 44100), events[0].length);
    try std.testing.expectEqual(@as(f64, 0.8), events[0].volume);

    try std.testing.expectEqual(@as(usize, 2), events[1].position.bar);
    try std.testing.expectEqual(@as(f64, 0.0), events[1].position.beat);
    try std.testing.expectApproxEqAbs(@as(f64, 329.63), events[1].freq, 1e-2);
    try std.testing.expectEqual(@as(usize, 22050), events[1].length);
    try std.testing.expectEqual(@as(f64, 0.6), events[1].volume);
}

test {
    std.testing.refAllDecls(@This());
}
