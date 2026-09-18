const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("../root.zig");
const Note = utils.note.Note;

pub fn Phrase(comptime T: type, comptime N: type) type {
    return struct {
        const Self = @This();

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

test {
    std.testing.refAllDecls(@This());
}
