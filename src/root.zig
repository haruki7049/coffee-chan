//! Main entry point for coffee-chan music composition and deterministic generation.
//!
//! Architectural Overview:
//! 1. Composition Setup: Instantiates a central `Sequencer(f64)` configured for 75 BPM,
//!    44.1 kHz sample rate, and 2-channel stereo output spanning a 24-bar arrangement:
//!    - Intro (Bars 0..3): 4 bars of acoustic guitar arpeggios and bass entry.
//!    - Section A (Bars 4..11): 8 bars of acoustic guitar, upright bass, and percussive rhythm.
//!    - Section B (Bars 12..19): 8 bars of full instrumentation adding electric piano melody.
//!    - Outro (Bars 20..23): 4 bars of acoustic guitar and bass decay.
//! 2. Subsystem Integration: Registers individual tracks ("Bass", "Percussion", "Melody")
//!    and multi-string instruments ("Guitar") streaming declarative phrases (`0000`, `0001`,
//!    `0002`, `0003`) into the timeline.
//! 3. Voice Scheduling & Rendering: Delegates timeline rendering to `VoiceScheduler` (handling
//!    the Single String Model and equal-power micro-fades) and `Renderer` (sample accumulation).
//! 4. DSP Post-Processing: Applies peak amplitude normalization via `filters.normalize` before
//!    returning the final `lightmix.Wave(f64)` for WAV file output (`coffee-chan.wav`).

const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const utils = @import("utils");

const T = f64;

/// Main composition pipeline function.
/// Renders a complete 24-bar arrangement at 75 BPM using acoustic guitar, upright bass,
/// percussive rhythm, and electric piano melody, followed by peak amplitude normalization.
pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 75;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var seq = utils.sequencer.Sequencer(T).init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    // 1. Instantiate Instruments and Tracks
    var guitar = try seq.createInstrument("Guitar", 6);
    defer guitar.deinit(allocator);

    _ = try seq.createTrack("Bass");
    _ = try seq.createTrack("Percussion");
    _ = try seq.createTrack("Melody");

    // Fetch pointers after all track creation is finished to avoid arraylist reallocation invalidation
    const bass_track = &seq.tracks.items[6];
    const percussion_track = &seq.tracks.items[7];
    const melody_track = &seq.tracks.items[8];

    percussion_track.enable_attack_fade = false; // Preserve percussive transient onsets

    // 4-Bar Jazz / Bossa-Nova Chord Progression Transpositions: | Fmaj7 | Em7 | Dm7 | Cmaj7 |
    const chord_transpositions = [_]isize{ 5, 4, 2, 0 };

    // 2. Intro (Bars 0..3 - 4 bars)
    // Transposed guitar arpeggios on every bar
    for (0..4) |b| {
        const trans = chord_transpositions[b % 4];
        try phrases._0002.loadInstrumentTransposed(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{ .bar = b, .beat = 0.0 }, VOLUME, trans);
    }
    // 4-bar walking bass line across bars 0..3
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 0, .beat = 0.0 }, VOLUME * 0.8);

    // 3. Section A (Bars 4..11 - 8 bars)
    // Transposed guitar arpeggios across bars 4..11
    for (4..12) |b| {
        const trans = chord_transpositions[b % 4];
        try phrases._0002.loadInstrumentTransposed(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{ .bar = b, .beat = 0.0 }, VOLUME, trans);
    }
    // 4-bar walking bass lines across bars 4..7 and 8..11
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 4, .beat = 0.0 }, VOLUME * 0.8);
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 8, .beat = 0.0 }, VOLUME * 0.8);

    // Percussive backbeat rhythm on beats 1 and 3 of every bar 4..11
    for (4..12) |b| {
        try phrases._0001.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, percussion_track, .{ .bar = b, .beat = 1.0 }, VOLUME * 0.4);
        try phrases._0001.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, percussion_track, .{ .bar = b, .beat = 3.0 }, VOLUME * 0.4);
    }

    // 4. Section B (Bars 12..19 - 8 bars)
    // Transposed guitar arpeggios across bars 12..19
    for (12..20) |b| {
        const trans = chord_transpositions[b % 4];
        try phrases._0002.loadInstrumentTransposed(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{ .bar = b, .beat = 0.0 }, VOLUME, trans);
    }
    // 4-bar walking bass lines across bars 12..15 and 16..19
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 12, .beat = 0.0 }, VOLUME * 0.8);
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 16, .beat = 0.0 }, VOLUME * 0.8);

    // Percussive backbeat rhythm on beats 1 and 3 of every bar 12..19
    for (12..20) |b| {
        try phrases._0001.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, percussion_track, .{ .bar = b, .beat = 1.0 }, VOLUME * 0.4);
        try phrases._0001.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, percussion_track, .{ .bar = b, .beat = 3.0 }, VOLUME * 0.4);
    }

    // Transposed electric piano / sine melody across bars 12..19 with decaying volume over bars 16..19
    for (12..20) |b| {
        const trans = chord_transpositions[b % 4];
        const vol_scale: T = switch (b) {
            16 => 0.7,
            17 => 0.5,
            18 => 0.3,
            19 => 0.15,
            else => 1.0,
        };
        try phrases._0000.loadTransposed(T, synthesizers.sine.Sine, utils.scale.Scale, &seq, melody_track, .{ .bar = b, .beat = 0.0 }, VOLUME * 0.7 * vol_scale, trans);
    }

    // 5. Outro (Bars 20..23 - 4 bars)
    // Transposed guitar arpeggios and bass through bars 20..22
    for (20..23) |b| {
        const trans = chord_transpositions[b % 4];
        try phrases._0002.loadInstrumentTransposed(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{ .bar = b, .beat = 0.0 }, VOLUME * 0.8, trans);
    }
    try phrases._0003.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, bass_track, .{ .bar = 20, .beat = 0.0 }, VOLUME * 0.7);

    // Bar 23: Final strummed resolution chord ("ジャララン") and high melody ending
    try phrases._0004.loadInstrument(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar, .{ .bar = 23, .beat = 0.0 }, VOLUME);

    // 6. Master & Peak Normalization
    var result: lightmix.Wave(T) = try seq.render();
    try filters.normalize(T, &result, 1.0);
    return result;
}

test "gen song via sequencer" {
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

    // Verify audio integrity: no NaN, no Inf, samples normalized within [-1.0, 1.0]
    var peak: T = 0.0;
    for (wave.samples) |s| {
        try std.testing.expect(!std.math.isNan(s));
        try std.testing.expect(!std.math.isInf(s));
        try std.testing.expect(s >= -1.0 and s <= 1.0);
        if (@abs(s) > peak) peak = @abs(s);
    }
    // Song must produce audible sound
    try std.testing.expect(peak > 0.0);
}
