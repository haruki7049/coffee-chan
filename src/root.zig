//! Main entry point for coffee-chan music composition and deterministic generation.
//!
//! Architectural Overview:
//! 1. Composition Setup: Instantiates a central `Sequencer(f64)` configured for 75 BPM,
//!    44.1 kHz sample rate, and 2-channel stereo output spanning a 48-bar Minimal Music arrangement:
//!    - Movement I: Ostinato Exposition (Bars 0..7 - 8 bars / 32 beats): Continuous analog vinyl crackle,
//!      hypnotic FM wood bass ostinato (Phrase 0007: Dm9 -> G13 -> CM7 across a 2-bar cycle), soft low-pass kick drum
//!      on beats 0.0 and 2.5, Layer 1 introducing the cafe jazz theme motif (Phrase 0005) softly on Rhodes piano,
//!      and gentle swing hi-hat entering at bar 4 to initiate the additive rhythmic groove.
//!    - Movement II: Additive Process & Phased Layering (Bars 8..23 - 16 bars / 64 beats): Through cumulative additive layering,
//!      rhythmic presence expands with fuller swing hi-hat, 5-voice Rhodes jazz chord comping (Phrase 0006) establishes
//!      the harmonic foundation, and Layer 2 enters phased with a 1-bar stagger to form an interlocking polyphonic minimalist counterpoint.
//!    - Movement III: Cumulative Density & Full Tutti (Bars 24..39 - 16 bars / 64 beats): Maximum ensemble density
//!      where Layer 3 enters (octave lower shadow), full Lo-Fi rhythm section (driving Kick + Swing Hi-Hat),
//!      rich 5-voice chord comping, and pulsing wood bass ostinato peak in dynamic energy.
//!    - Movement IV: Coda & Dissolution (Bars 40..47 - 8 bars / 32 beats): Melodic layers resolve and exit
//!      progressively, drums drop out, concluding with a sustaining CM7 harmonic tail on Rhodes and Wood Bass
//!      with a warm exponential decay, while vinyl crackle gently fades into silence at bar 48 (~2.5 minutes).
//! 2. Subsystem Integration: Registers individual tracks ("VinylNoise", "Bass", "Kick", "HiHat")
//!    and multi-voice instruments ("RhodesChords", "ThemeLayers") streaming declarative phrases
//!    (`0005`, `0006`, `0007`) and synthesizer generators into the timeline.
//! 3. Voice Scheduling & Rendering: Delegates timeline rendering to `VoiceScheduler` and `Renderer`.
//! 4. DSP Post-Processing: Applies peak amplitude normalization via `filters.normalize` before
//!    returning the final `lightmix.Wave(f64)` for WAV file output (`coffee-chan.wav`).

const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const utils = @import("utils");

const T = f64;

fn createKickWave(allocator: std.mem.Allocator, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(75, sample_rate));
    const kick_len: usize = @intFromFloat(spb_val * 0.4);
    var wave = try synthesizers.sine.Sine.gen(T, allocator, 60.0, sample_rate, channels, kick_len, volume, .{});
    try filters.decay(T, &wave);
    return wave;
}

fn createHiHatWave(allocator: std.mem.Allocator, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(75, sample_rate));
    const hat_len: usize = @intFromFloat(spb_val * 0.15);
    var wave = try synthesizers.whitenoise.WhiteNoise.gen(T, allocator, sample_rate, channels, hat_len, volume);
    try filters.decay(T, &wave);
    return wave;
}

/// Main composition pipeline function.
/// Renders a complete 48-bar Minimal Music arrangement at 75 BPM (~2.5 minutes)
/// followed by peak amplitude normalization.
pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 75;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var seq = utils.sequencer.Sequencer(T).init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    // 1. Instantiate Instruments and Tracks
    const vinyl_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("VinylNoise");

    const bass_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("Bass");

    var rhodes_chords = try seq.createInstrument("RhodesChords", 5);
    defer rhodes_chords.deinit(allocator);

    var theme_layers = try seq.createInstrument("ThemeLayers", 3);
    defer theme_layers.deinit(allocator);

    const kick_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("Kick");

    const hihat_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("HiHat");

    // Fetch pointers after all creations to avoid array reallocation invalidation
    const vinyl_track = &seq.tracks.items[vinyl_track_idx];
    const bass_track = &seq.tracks.items[bass_track_idx];
    const kick_track = &seq.tracks.items[kick_track_idx];
    const hihat_track = &seq.tracks.items[hihat_track_idx];

    kick_track.enable_attack_fade = false;
    hihat_track.enable_attack_fade = false;

    const spb_val = utils.tempo.spb(BPM, SAMPLE_RATE);
    const total_bars: usize = 48;
    const total_beats = total_bars * 4;
    const total_samples = total_beats * spb_val;

    // Continuous Vinyl Crackle Atmosphere across 48 bars with fading tail during the final 4 bars
    var vinyl_samples = try synthesizers.vinyl_noise.VinylNoise.array(
        T,
        allocator,
        0.0,
        SAMPLE_RATE,
        CHANNELS,
        total_samples,
        VOLUME * 0.04,
        .{},
    );
    const fade_start_sample = 44 * 4 * spb_val;
    if (fade_start_sample < total_samples) {
        const fade_len = total_samples - fade_start_sample;
        for (fade_start_sample..total_samples) |i| {
            const remaining = total_samples - i;
            const factor = @as(T, @floatFromInt(remaining)) / @as(T, @floatFromInt(fade_len));
            for (0..CHANNELS) |ch| {
                vinyl_samples[i * CHANNELS + ch] *= factor;
            }
        }
    }
    const vinyl_wave = lightmix.Wave(T){
        .allocator = allocator,
        .samples = vinyl_samples,
        .sample_rate = SAMPLE_RATE,
        .channels = CHANNELS,
    };
    try seq.add(vinyl_track, vinyl_wave, .{ .bar = 0, .beat = 0.0 });

    // 2. Movement I: Ostinato Exposition (Bars 0..7 - 8 bars / 32 beats)
    // II-V-I Ground Bass Ostinato (Phrase 0007: 2 bars x 4 repetitions)
    var m1_bar: usize = 0;
    while (m1_bar < 8) : (m1_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m1_bar, .beat = 0.0 }, VOLUME * 0.85);
    }

    // Soft low-pass kick on beats 0.0 and 2.5
    for (0..8) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.45), .{ .bar = b, .beat = 2.5 });
    }

    // Layer 1 introduces primary cafe jazz theme (Phrase 0005: 2 bars x 4 repetitions)
    const layer1_only = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
    };
    var m1_vbar: usize = 0;
    while (m1_vbar < 8) : (m1_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m1_vbar, .beat = 0.0 }, layer1_only);
    }

    // Swing Hi-Hat enters gently at bar 4 (bars 4..7)
    for (4..8) |b| {
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.22), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.08), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // 3. Movement II: Additive Process & Phased Layering (Bars 8..23 - 16 bars / 64 beats)
    // II-V-I Ground Bass Ostinato across 8 cycles of 2 bars
    var m2_bar: usize = 8;
    while (m2_bar < 24) : (m2_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m2_bar, .beat = 0.0 }, VOLUME * 0.85);
    }

    // Rhodes jazz chord comping (Phrase 0006: 2 bars x 8 repetitions)
    var m2_cbar: usize = 8;
    while (m2_cbar < 24) : (m2_cbar += 2) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m2_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }

    // Drums: Kick on beats 0.0 and 2.5, Swing Hi-Hat on each beat (0.00 accent, 0.75 ghost)
    for (8..24) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.60), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.50), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.30), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.12), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Additive Melodic Layers: Layer 1 (string 0) and Layer 2 (string 1, 1-bar phased offset)
    const dual_layers = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
        .{ .bar_offset = 1, .string_index = 1, .volume = 0.75, .octaves = 0 },
    };
    var m2_vbar: usize = 8;
    while (m2_vbar < 24) : (m2_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m2_vbar, .beat = 0.0 }, dual_layers);
    }

    // 4. Movement III: Additive Crescendo & Full Tutti (Bars 24..39 - 16 bars / 64 beats)
    // II-V-I Ground Bass Ostinato across 8 cycles of 2 bars
    var m3_bar: usize = 24;
    while (m3_bar < 40) : (m3_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m3_bar, .beat = 0.0 }, VOLUME * 0.85);
    }

    // Rhodes jazz chord comping (Phrase 0006: 2 bars x 8 repetitions)
    var m3_cbar: usize = 24;
    while (m3_cbar < 40) : (m3_cbar += 2) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m3_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }

    // Full Lo-Fi rhythm section: Kick and Swing Hi-Hat
    for (24..40) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.65), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.32), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.14), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Full 3-layer Tutti: Layer 1 (offset 0), Layer 2 (offset 1), Layer 3 (offset 0, octave -1)
    const tri_layers = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.75 },
        .{ .bar_offset = 1, .string_index = 1, .volume = 0.70, .octaves = 0 },
        .{ .bar_offset = 0, .string_index = 2, .volume = 0.65, .octaves = -1 },
    };
    var m3_vbar: usize = 24;
    while (m3_vbar < 40) : (m3_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m3_vbar, .beat = 0.0 }, tri_layers);
    }

    // 5. Movement IV: Coda & Dissolution (Bars 40..47 - 8 bars / 32 beats)
    // Ground Bass plays bars 40..43 (2 cycles of 2 bars, gently diminishing)
    var m4_b: usize = 40;
    while (m4_b < 44) : (m4_b += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m4_b, .beat = 0.0 }, VOLUME * 0.75);
    }

    // Rhodes chord comping plays bars 40..43 (2 cycles of 2 bars)
    var m4_cb: usize = 40;
    while (m4_cb < 44) : (m4_cb += 2) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m4_cb, .beat = 0.0 }, VOLUME * 0.55);
    }

    // Melodic layers resolve and dissolve progressively
    // Bars 40..43: Layer 1 and Layer 2 play 2 cycles
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 40, .beat = 0.0 }, dual_layers);
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 42, .beat = 0.0 }, dual_layers);

    // Bars 44..47 (4 bars): Sustaining CM7 harmonic tail on Rhodes and Bass with warm decay
    const coda_len: usize = 4 * 4 * spb_val;
    const coda_chord_notes = [_]utils.scale.Scale{
        .{ .code = .c, .octave = 3 },
        .{ .code = .e, .octave = 3 },
        .{ .code = .g, .octave = 3 },
        .{ .code = .b, .octave = 3 },
        .{ .code = .e, .octave = 4 },
    };
    for (coda_chord_notes, 0..) |note, str_idx| {
        var chord_wave = try synthesizers.rhodes.Rhodes.gen(
            T,
            allocator,
            note.gen(),
            SAMPLE_RATE,
            CHANNELS,
            coda_len,
            VOLUME * 0.60,
            .{ .decay_rate = 0.5 },
        );
        try filters.decay(T, &chord_wave);
        try seq.addInstrument(rhodes_chords, str_idx, chord_wave, .{ .bar = 44, .beat = 0.0 });
    }

    const bass_root = utils.scale.Scale{ .code = .c, .octave = 2 };
    var bass_coda_wave = try synthesizers.wood_bass.WoodBass.gen(
        T,
        allocator,
        bass_root.gen(),
        SAMPLE_RATE,
        CHANNELS,
        coda_len,
        VOLUME * 0.75,
        .{},
    );
    try filters.decay(T, &bass_coda_wave);
    try seq.add(bass_track, bass_coda_wave, .{ .bar = 44, .beat = 0.0 });

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

    // Verify 48-bar length (192 beats @ 75 BPM = 6,773,760 frames * 2 channels = 13,547,520 samples)
    try std.testing.expectEqual(@as(usize, 6773760 * 2), wave.samples.len);

    // Verify audio integrity: no NaN, no Inf, samples normalized within [-1.0, 1.0]
    var peak: T = 0.0;
    for (wave.samples) |s| {
        try std.testing.expect(!std.math.isNan(s));
        try std.testing.expect(!std.math.isInf(s));
        try std.testing.expect(s >= -1.0 and s <= 1.0);
        if (@abs(s) > peak) peak = @abs(s);
    }
    // Song must produce audible sound and reach normalized peak
    try std.testing.expectApproxEqAbs(@as(T, 1.0), peak, 1e-4);
}
