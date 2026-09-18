const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const T = f64;
const Scale = utils.scale.Scale;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;
const Sequencer = utils.sequencer.Sequencer(T);
const Instrument = utils.sequencer.Instrument(T);

fn playNote(
    seq: *Sequencer,
    guitar: Instrument,
    string: usize,
    code: Scale.Code,
    octave: usize,
    bar: usize,
    beat: f64,
    duration_beats: f64,
    volume: T,
) !void {
    const spb_f: f64 = @floatFromInt(utils.tempo.spb(seq.bpm, seq.sample_rate));
    // Decouple musical beat duration from audio buffer length so string vibration decays naturally:
    // When a note is plucked on an acoustic guitar, the string resonates for 2.5–3.5+ seconds
    // unless superseded or muted. VoiceScheduler handles micro-fade truncation cleanly
    // whenever another note is plucked on the same string.
    const sustain_beats: f64 = @max(duration_beats, 3.5);
    const length: usize = @intFromFloat(spb_f * sustain_beats);
    const freq = Scale.gen(.{ .code = code, .octave = octave });

    // Lower strings use pick smoothing filter to enhance deep fundamentals
    const lpf_passes: usize = if (string >= 4) 2 else (if (string >= 2) 1 else 0);
    // Warm, singing acoustic sustain
    const feedback: T = if (string >= 4) 0.996 else 0.9965;

    const wave = try KarplusStrong.gen(
        T,
        seq.allocator,
        freq,
        seq.sample_rate,
        seq.channels,
        length,
        volume,
        .{
            .feedback = feedback,
            .excitation_lpf_passes = lpf_passes,
            .filter_weight = 0.5,
        },
    );

    try seq.addInstrument(guitar, string, wave, .{ .bar = bar, .beat = beat });
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

    // --- Bar 0: Am9 (Atmospheric Opening) ---
    // Bass
    try playNote(&seq, guitar, 5, .a, 2, 0, 0.0, 2.0, 0.80);
    try playNote(&seq, guitar, 4, .e, 3, 0, 2.0, 2.0, 0.70);
    // Comping
    try playNote(&seq, guitar, 2, .c, 4, 0, 0.5, 2.0, 0.55);
    try playNote(&seq, guitar, 1, .e, 4, 0, 1.0, 2.0, 0.55);
    try playNote(&seq, guitar, 1, .g, 4, 0, 1.5, 1.5, 0.50);
    // Lead Melody (Warm, lyrical phrasing)
    try playNote(&seq, guitar, 0, .b, 4, 0, 2.0, 1.0, 0.85);
    try playNote(&seq, guitar, 0, .c, 5, 0, 3.0, 1.0, 0.90);

    // --- Bar 1: Fmaj7#11 (Lyrical Ascending Run with Lydian color) ---
    // Bass
    try playNote(&seq, guitar, 5, .f, 2, 1, 0.0, 2.0, 0.85);
    try playNote(&seq, guitar, 4, .c, 3, 1, 2.0, 2.0, 0.70);
    // Comping
    try playNote(&seq, guitar, 3, .a, 3, 1, 0.5, 2.0, 0.55);
    try playNote(&seq, guitar, 2, .e, 4, 1, 1.0, 2.0, 0.55);
    // Lead Melody
    try playNote(&seq, guitar, 0, .g, 4, 1, 1.0, 1.0, 0.80);
    try playNote(&seq, guitar, 0, .a, 4, 1, 2.0, 0.5, 0.85);
    try playNote(&seq, guitar, 0, .b, 4, 1, 2.5, 0.5, 0.90);
    try playNote(&seq, guitar, 0, .e, 5, 1, 3.0, 1.5, 0.95);

    // --- Bar 2: Dm9 (Soaring Climax) ---
    // Bass
    try playNote(&seq, guitar, 4, .d, 3, 2, 0.0, 2.0, 0.85);
    try playNote(&seq, guitar, 5, .a, 2, 2, 2.0, 2.0, 0.70);
    // Comping
    try playNote(&seq, guitar, 3, .f, 3, 2, 0.5, 2.0, 0.55);
    try playNote(&seq, guitar, 2, .c, 4, 2, 1.0, 2.0, 0.55);
    // Lead Melody (High expressive peak sustained gracefully)
    try playNote(&seq, guitar, 0, .f, 5, 2, 0.0, 1.5, 0.95);
    try playNote(&seq, guitar, 0, .e, 5, 2, 1.5, 0.5, 0.85);
    try playNote(&seq, guitar, 0, .d, 5, 2, 2.0, 1.0, 0.85);
    try playNote(&seq, guitar, 1, .a, 4, 2, 3.0, 1.5, 0.80);

    // --- Bar 3: E7alt / E7b9 (Spanish/Jazz Chromatic Tension) ---
    // Bass
    try playNote(&seq, guitar, 5, .e, 2, 3, 0.0, 2.0, 0.90);
    try playNote(&seq, guitar, 5, .b, 2, 3, 2.0, 2.0, 0.75);
    // Comping
    try playNote(&seq, guitar, 3, .gs, 3, 3, 0.5, 2.0, 0.60);
    try playNote(&seq, guitar, 2, .d, 4, 3, 1.0, 2.0, 0.60);
    // Lead Melody (Chromatic tension into resolution)
    try playNote(&seq, guitar, 1, .f, 4, 3, 1.0, 1.0, 0.80);
    try playNote(&seq, guitar, 1, .e, 4, 3, 2.0, 0.5, 0.85);
    try playNote(&seq, guitar, 1, .ds, 4, 3, 2.5, 0.5, 0.80);
    try playNote(&seq, guitar, 0, .gs, 4, 3, 3.0, 1.5, 0.90);

    // --- Bar 4: Am9 (Smooth Resolution & Blues Flourish) ---
    // Bass
    try playNote(&seq, guitar, 5, .a, 2, 4, 0.0, 2.0, 0.85);
    try playNote(&seq, guitar, 5, .g, 2, 4, 2.0, 2.0, 0.75);
    // Comping
    try playNote(&seq, guitar, 2, .c, 4, 4, 0.5, 2.0, 0.55);
    try playNote(&seq, guitar, 1, .g, 4, 4, 1.0, 2.0, 0.55);
    // Lead Melody
    try playNote(&seq, guitar, 0, .a, 4, 4, 0.5, 1.5, 0.90);
    try playNote(&seq, guitar, 0, .c, 5, 4, 2.0, 0.5, 0.85);
    try playNote(&seq, guitar, 0, .d, 5, 4, 2.5, 0.5, 0.85);
    try playNote(&seq, guitar, 0, .e, 5, 4, 3.0, 1.5, 0.90);

    // --- Bar 5: Dm9 -> G13 (Cafe Swing) ---
    // Bass
    try playNote(&seq, guitar, 4, .d, 3, 5, 0.0, 2.0, 0.80);
    try playNote(&seq, guitar, 5, .g, 2, 5, 2.0, 2.0, 0.80);
    // Comping
    try playNote(&seq, guitar, 3, .f, 3, 5, 0.5, 2.0, 0.50);
    try playNote(&seq, guitar, 2, .b, 3, 5, 2.5, 2.0, 0.55);
    // Lead Melody
    try playNote(&seq, guitar, 0, .a, 4, 5, 0.5, 1.0, 0.80);
    try playNote(&seq, guitar, 1, .f, 4, 5, 1.5, 0.5, 0.75);
    try playNote(&seq, guitar, 0, .e, 5, 5, 2.0, 1.0, 0.90);
    try playNote(&seq, guitar, 0, .b, 4, 5, 3.0, 1.5, 0.85);

    // --- Bar 6: Cmaj7 -> Fmaj7 (Falling Autumn Leaves Motion) ---
    // Bass
    try playNote(&seq, guitar, 4, .c, 3, 6, 0.0, 2.0, 0.85);
    try playNote(&seq, guitar, 5, .f, 2, 6, 2.0, 2.0, 0.85);
    // Comping
    try playNote(&seq, guitar, 3, .e, 3, 6, 0.5, 2.0, 0.55);
    try playNote(&seq, guitar, 2, .b, 3, 6, 1.0, 2.0, 0.55);
    // Lead Melody
    try playNote(&seq, guitar, 1, .g, 4, 6, 0.5, 1.0, 0.80);
    try playNote(&seq, guitar, 1, .e, 4, 6, 1.5, 0.5, 0.75);
    try playNote(&seq, guitar, 0, .a, 4, 6, 2.0, 1.0, 0.85);
    try playNote(&seq, guitar, 0, .e, 5, 6, 3.0, 1.5, 0.90);

    // --- Bar 7: Bm7b5 -> E7alt -> Am(add9) (Delicate Final Rolled Chord) ---
    // Bass
    try playNote(&seq, guitar, 5, .b, 2, 7, 0.0, 1.0, 0.80);
    try playNote(&seq, guitar, 5, .e, 2, 7, 1.0, 1.0, 0.85);
    // Cadence
    try playNote(&seq, guitar, 2, .d, 4, 7, 0.5, 0.5, 0.70);
    try playNote(&seq, guitar, 1, .gs, 4, 7, 1.0, 0.5, 0.80);
    try playNote(&seq, guitar, 0, .d, 5, 7, 1.5, 0.5, 0.80);
    // Final Rolled Am(add9) Chord (Rings freely with sustained natural decay)
    try playNote(&seq, guitar, 5, .a, 2, 7, 2.0, 4.0, 0.90);
    try playNote(&seq, guitar, 4, .e, 3, 7, 2.1, 4.0, 0.75);
    try playNote(&seq, guitar, 3, .a, 3, 7, 2.2, 4.0, 0.75);
    try playNote(&seq, guitar, 2, .c, 4, 7, 2.3, 4.0, 0.75);
    try playNote(&seq, guitar, 1, .e, 4, 7, 2.4, 4.0, 0.75);
    try playNote(&seq, guitar, 0, .b, 4, 7, 2.5, 4.0, 0.85);

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
