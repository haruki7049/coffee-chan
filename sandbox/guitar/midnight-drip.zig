const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const music = @import("music");
const sequencer = @import("sequencer");
const phrases = @import("phrases");
const guitar_synth = @import("guitar.zig");

const T = f64;
const Scale = music.scale.Scale;
const Sequencer = sequencer.Sequencer(T);
const Instrument = sequencer.Instrument(T);
const RawNote = phrases.Phrase(T, Scale).RawNote;

/// Sound generator for nylon/steel cafe guitar acoustics (treble feedback 0.9965).
pub const GuitarSoundGen = guitar_synth.SoundGen(0.9965);

/// 8-bar cafe acoustic fingerstyle guitar solo composition in A minor.
/// Defined using the Phrase system and unified in this single file.
pub const phrase: phrases.Phrase(T, Scale) = .{
    .name = "Midnight Drip",
    .notes = &[_]RawNote{
        // --- Bar 0: Am9 (Atmospheric Opening) ---
        // Bass
        .{ .bar = 0, .beat = 0.0, .note = .{ .code = .a, .octave = 2 }, .duration_beats = 2.0, .volume = 0.80, .string = 5 },
        .{ .bar = 0, .beat = 2.0, .note = .{ .code = .e, .octave = 3 }, .duration_beats = 2.0, .volume = 0.70, .string = 4 },
        // Comping
        .{ .bar = 0, .beat = 0.5, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        .{ .bar = 0, .beat = 1.0, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 1 },
        .{ .bar = 0, .beat = 1.5, .note = .{ .code = .g, .octave = 4 }, .duration_beats = 1.5, .volume = 0.50, .string = 1 },
        // Lead Melody (Warm, lyrical phrasing)
        .{ .bar = 0, .beat = 2.0, .note = .{ .code = .b, .octave = 4 }, .duration_beats = 1.0, .volume = 0.85, .string = 0 },
        .{ .bar = 0, .beat = 3.0, .note = .{ .code = .c, .octave = 5 }, .duration_beats = 1.0, .volume = 0.90, .string = 0 },

        // --- Bar 1: Fmaj7#11 (Lyrical Ascending Run with Lydian color) ---
        // Bass
        .{ .bar = 1, .beat = 0.0, .note = .{ .code = .f, .octave = 2 }, .duration_beats = 2.0, .volume = 0.85, .string = 5 },
        .{ .bar = 1, .beat = 2.0, .note = .{ .code = .c, .octave = 3 }, .duration_beats = 2.0, .volume = 0.70, .string = 4 },
        // Comping
        .{ .bar = 1, .beat = 0.5, .note = .{ .code = .a, .octave = 3 }, .duration_beats = 2.0, .volume = 0.55, .string = 3 },
        .{ .bar = 1, .beat = 1.0, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        // Lead Melody
        .{ .bar = 1, .beat = 1.0, .note = .{ .code = .g, .octave = 4 }, .duration_beats = 1.0, .volume = 0.80, .string = 0 },
        .{ .bar = 1, .beat = 2.0, .note = .{ .code = .a, .octave = 4 }, .duration_beats = 0.5, .volume = 0.85, .string = 0 },
        .{ .bar = 1, .beat = 2.5, .note = .{ .code = .b, .octave = 4 }, .duration_beats = 0.5, .volume = 0.90, .string = 0 },
        .{ .bar = 1, .beat = 3.0, .note = .{ .code = .e, .octave = 5 }, .duration_beats = 1.5, .volume = 0.95, .string = 0 },

        // --- Bar 2: Dm9 (Soaring Climax) ---
        // Bass
        .{ .bar = 2, .beat = 0.0, .note = .{ .code = .d, .octave = 3 }, .duration_beats = 2.0, .volume = 0.85, .string = 4 },
        .{ .bar = 2, .beat = 2.0, .note = .{ .code = .a, .octave = 2 }, .duration_beats = 2.0, .volume = 0.70, .string = 5 },
        // Comping
        .{ .bar = 2, .beat = 0.5, .note = .{ .code = .f, .octave = 3 }, .duration_beats = 2.0, .volume = 0.55, .string = 3 },
        .{ .bar = 2, .beat = 1.0, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        // Lead Melody (High expressive peak sustained gracefully)
        .{ .bar = 2, .beat = 0.0, .note = .{ .code = .f, .octave = 5 }, .duration_beats = 1.5, .volume = 0.95, .string = 0 },
        .{ .bar = 2, .beat = 1.5, .note = .{ .code = .e, .octave = 5 }, .duration_beats = 0.5, .volume = 0.85, .string = 0 },
        .{ .bar = 2, .beat = 2.0, .note = .{ .code = .d, .octave = 5 }, .duration_beats = 1.0, .volume = 0.85, .string = 0 },
        .{ .bar = 2, .beat = 3.0, .note = .{ .code = .a, .octave = 4 }, .duration_beats = 1.5, .volume = 0.80, .string = 1 },

        // --- Bar 3: E7alt / E7b9 (Spanish/Jazz Chromatic Tension) ---
        // Bass
        .{ .bar = 3, .beat = 0.0, .note = .{ .code = .e, .octave = 2 }, .duration_beats = 2.0, .volume = 0.90, .string = 5 },
        .{ .bar = 3, .beat = 2.0, .note = .{ .code = .b, .octave = 2 }, .duration_beats = 2.0, .volume = 0.75, .string = 5 },
        // Comping
        .{ .bar = 3, .beat = 0.5, .note = .{ .code = .gs, .octave = 3 }, .duration_beats = 2.0, .volume = 0.60, .string = 3 },
        .{ .bar = 3, .beat = 1.0, .note = .{ .code = .d, .octave = 4 }, .duration_beats = 2.0, .volume = 0.60, .string = 2 },
        // Lead Melody (Chromatic tension into resolution)
        .{ .bar = 3, .beat = 1.0, .note = .{ .code = .f, .octave = 4 }, .duration_beats = 1.0, .volume = 0.80, .string = 1 },
        .{ .bar = 3, .beat = 2.0, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 0.5, .volume = 0.85, .string = 1 },
        .{ .bar = 3, .beat = 2.5, .note = .{ .code = .ds, .octave = 4 }, .duration_beats = 0.5, .volume = 0.80, .string = 1 },
        .{ .bar = 3, .beat = 3.0, .note = .{ .code = .gs, .octave = 4 }, .duration_beats = 1.5, .volume = 0.90, .string = 0 },

        // --- Bar 4: Am9 (Smooth Resolution & Blues Flourish) ---
        // Bass
        .{ .bar = 4, .beat = 0.0, .note = .{ .code = .a, .octave = 2 }, .duration_beats = 2.0, .volume = 0.85, .string = 5 },
        .{ .bar = 4, .beat = 2.0, .note = .{ .code = .g, .octave = 2 }, .duration_beats = 2.0, .volume = 0.75, .string = 5 },
        // Comping
        .{ .bar = 4, .beat = 0.5, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        .{ .bar = 4, .beat = 1.0, .note = .{ .code = .g, .octave = 4 }, .duration_beats = 2.0, .volume = 0.55, .string = 1 },
        // Lead Melody
        .{ .bar = 4, .beat = 0.5, .note = .{ .code = .a, .octave = 4 }, .duration_beats = 1.5, .volume = 0.90, .string = 0 },
        .{ .bar = 4, .beat = 2.0, .note = .{ .code = .c, .octave = 5 }, .duration_beats = 0.5, .volume = 0.85, .string = 0 },
        .{ .bar = 4, .beat = 2.5, .note = .{ .code = .d, .octave = 5 }, .duration_beats = 0.5, .volume = 0.85, .string = 0 },
        .{ .bar = 4, .beat = 3.0, .note = .{ .code = .e, .octave = 5 }, .duration_beats = 1.5, .volume = 0.90, .string = 0 },

        // --- Bar 5: Dm9 -> G13 (Cafe Swing) ---
        // Bass
        .{ .bar = 5, .beat = 0.0, .note = .{ .code = .d, .octave = 3 }, .duration_beats = 2.0, .volume = 0.80, .string = 4 },
        .{ .bar = 5, .beat = 2.0, .note = .{ .code = .g, .octave = 2 }, .duration_beats = 2.0, .volume = 0.80, .string = 5 },
        // Comping
        .{ .bar = 5, .beat = 0.5, .note = .{ .code = .f, .octave = 3 }, .duration_beats = 2.0, .volume = 0.50, .string = 3 },
        .{ .bar = 5, .beat = 2.5, .note = .{ .code = .b, .octave = 3 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        // Lead Melody
        .{ .bar = 5, .beat = 0.5, .note = .{ .code = .a, .octave = 4 }, .duration_beats = 1.0, .volume = 0.80, .string = 0 },
        .{ .bar = 5, .beat = 1.5, .note = .{ .code = .f, .octave = 4 }, .duration_beats = 0.5, .volume = 0.75, .string = 1 },
        .{ .bar = 5, .beat = 2.0, .note = .{ .code = .e, .octave = 5 }, .duration_beats = 1.0, .volume = 0.90, .string = 0 },
        .{ .bar = 5, .beat = 3.0, .note = .{ .code = .b, .octave = 4 }, .duration_beats = 1.5, .volume = 0.85, .string = 0 },

        // --- Bar 6: Cmaj7 -> Fmaj7 (Falling Autumn Leaves Motion) ---
        // Bass
        .{ .bar = 6, .beat = 0.0, .note = .{ .code = .c, .octave = 3 }, .duration_beats = 2.0, .volume = 0.85, .string = 4 },
        .{ .bar = 6, .beat = 2.0, .note = .{ .code = .f, .octave = 2 }, .duration_beats = 2.0, .volume = 0.85, .string = 5 },
        // Comping
        .{ .bar = 6, .beat = 0.5, .note = .{ .code = .e, .octave = 3 }, .duration_beats = 2.0, .volume = 0.55, .string = 3 },
        .{ .bar = 6, .beat = 1.0, .note = .{ .code = .b, .octave = 3 }, .duration_beats = 2.0, .volume = 0.55, .string = 2 },
        // Lead Melody
        .{ .bar = 6, .beat = 0.5, .note = .{ .code = .g, .octave = 4 }, .duration_beats = 1.0, .volume = 0.80, .string = 1 },
        .{ .bar = 6, .beat = 1.5, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 0.5, .volume = 0.75, .string = 1 },
        .{ .bar = 6, .beat = 2.0, .note = .{ .code = .a, .octave = 4 }, .duration_beats = 1.0, .volume = 0.85, .string = 0 },
        .{ .bar = 6, .beat = 3.0, .note = .{ .code = .e, .octave = 5 }, .duration_beats = 1.5, .volume = 0.90, .string = 0 },

        // --- Bar 7: Bm7b5 -> E7alt -> Am(add9) (Delicate Final Rolled Chord) ---
        // Bass
        .{ .bar = 7, .beat = 0.0, .note = .{ .code = .b, .octave = 2 }, .duration_beats = 1.0, .volume = 0.80, .string = 5 },
        .{ .bar = 7, .beat = 1.0, .note = .{ .code = .e, .octave = 2 }, .duration_beats = 1.0, .volume = 0.85, .string = 5 },
        // Cadence
        .{ .bar = 7, .beat = 0.5, .note = .{ .code = .d, .octave = 4 }, .duration_beats = 0.5, .volume = 0.70, .string = 2 },
        .{ .bar = 7, .beat = 1.0, .note = .{ .code = .gs, .octave = 4 }, .duration_beats = 0.5, .volume = 0.80, .string = 1 },
        .{ .bar = 7, .beat = 1.5, .note = .{ .code = .d, .octave = 5 }, .duration_beats = 0.5, .volume = 0.80, .string = 0 },
        // Final Rolled Am(add9) Chord (Rings freely with sustained natural decay)
        .{ .bar = 7, .beat = 2.0, .note = .{ .code = .a, .octave = 2 }, .duration_beats = 4.0, .volume = 0.90, .string = 5 },
        .{ .bar = 7, .beat = 2.1, .note = .{ .code = .e, .octave = 3 }, .duration_beats = 4.0, .volume = 0.75, .string = 4 },
        .{ .bar = 7, .beat = 2.2, .note = .{ .code = .a, .octave = 3 }, .duration_beats = 4.0, .volume = 0.75, .string = 3 },
        .{ .bar = 7, .beat = 2.3, .note = .{ .code = .c, .octave = 4 }, .duration_beats = 4.0, .volume = 0.75, .string = 2 },
        .{ .bar = 7, .beat = 2.4, .note = .{ .code = .e, .octave = 4 }, .duration_beats = 4.0, .volume = 0.75, .string = 1 },
        .{ .bar = 7, .beat = 2.5, .note = .{ .code = .b, .octave = 4 }, .duration_beats = 4.0, .volume = 0.85, .string = 0 },
    },
};

pub fn toEvents(
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
) ![]music.note.Note(T) {
    return try phrase.toEvents(Scale, allocator, bpm, sample_rate);
}

pub fn loadInstrument(
    seq: *Sequencer,
    instrument: Instrument,
    start_position: music.position.Position,
    volume: T,
) !void {
    try phrase.loadInstrument(GuitarSoundGen, Scale, seq, instrument, start_position, volume);
}

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 78;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;

    var seq = Sequencer.init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    // 6-string acoustic guitar:
    // Strings 4 & 5: thumb bass (E2/A2/D3 range)
    // Strings 2 & 3: middle comping arpeggios & chord resonance
    // Strings 0 & 1: singing lead melody (B3–F5 range)
    var guitar = try seq.createInstrument("AcousticGuitar", 6);
    defer guitar.deinit(allocator);

    try loadInstrument(&seq, guitar, .{ .bar = 0, .beat = 0.0 }, 1.0);

    var result = try seq.render();
    try filters.normalize(T, &result, 0.95);
    return result;
}

test "generate midnight-drip guitar solo in sandbox" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const proc_init = std.process.Init{
        .minimal = .{
            .environ = undefined,
            .args = undefined,
        },
        .gpa = std.testing.allocator,
        .arena = &arena,
        .io = undefined,
        .environ_map = undefined,
        .preopens = undefined,
    };

    var wave = try gen(proc_init);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);

    // Audio integrity check
    var peak: T = 0.0;
    for (wave.samples) |s| {
        try std.testing.expect(!std.math.isNan(s));
        try std.testing.expect(!std.math.isInf(s));
        try std.testing.expect(s >= -1.0 and s <= 1.0);
        if (@abs(s) > peak) peak = @abs(s);
    }
    try std.testing.expect(peak > 0.0);
}

test "midnight-drip phrase toEvents" {
    const allocator = std.testing.allocator;
    const events = try toEvents(allocator, 78, 44100);
    defer allocator.free(events);
    try std.testing.expectEqual(phrase.notes.len, events.len);
}
