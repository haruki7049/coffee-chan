//! Main entry point for coffee-chan music composition and deterministic generation.
//!
//! Architectural Overview:
//! 1. Composition Setup: Instantiates a central `Sequencer(f64)` configured for 75 BPM,
//!    44.1 kHz sample rate, and 2-channel stereo output spanning a 96-bar Minimal Music arrangement:
//!    - Part 1: Initial Minimal Build (Bars 0..47 - 48 bars):
//!      - Bars 0..7: Ostinato Exposition (Wood bass + kick, hi-hat from bar 4, solo Rhodes melody).
//!      - Bars 8..23: Additive Process (5-voice Rhodes chords + Layer 2 phased counterpoint).
//!      - Bars 24..39: Cumulative Density (Layer 3 octave shadow + driving Lo-Fi tutti).
//!      - Bars 40..47: Bridge & Deceleration leading into Part 2.
//!    - Part 2: Bossa Nova Syncopated Groove Development (Bars 48..95 - 48 bars):
//!      - Bars 48..79: Syncopated Latin cafe groove featuring off-beat Bossa kick, 16th-note swing hat,
//!        syncopated Rhodes comping, and rhythmic motif variations.
//!      - Bars 80..87: Progressive groove deceleration and wind-down.
//!      - Bars 88..95: Sustaining CM7 harmonic tail on Rhodes and Bass with warm exponential decay,
//!        while vinyl crackle gently fades into silence at bar 96 (~5 minutes).
//! 2. Subsystem Integration: Registers individual tracks ("VinylNoise", "Bass", "Kick", "HiHat")
//!    and multi-voice instruments ("RhodesChords", "ThemeLayers").
//! 3. Voice Scheduling & Rendering: Delegates timeline rendering to `VoiceScheduler` and `Renderer`.
//! 4. DSP Post-Processing: Applies peak amplitude normalization via `filters.normalize`.

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
/// Renders a complete 96-bar Minimal Music arrangement with Bossa Nova Part 2 at 75 BPM (~5 minutes)
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

    const vinyl_track = &seq.tracks.items[vinyl_track_idx];
    const bass_track = &seq.tracks.items[bass_track_idx];
    const kick_track = &seq.tracks.items[kick_track_idx];
    const hihat_track = &seq.tracks.items[hihat_track_idx];

    kick_track.enable_attack_fade = false;
    hihat_track.enable_attack_fade = false;

    const spb_val = utils.tempo.spb(BPM, SAMPLE_RATE);
    const total_bars: usize = 96;
    const total_beats = total_bars * 4;
    const total_samples = total_beats * spb_val;

    // Continuous Vinyl Crackle Atmosphere across 96 bars with fading tail during the final 8 bars
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
    const fade_start_sample = 88 * 4 * spb_val;
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

    // ==========================================
    // PART 1: MINIMAL ACCUMULATION (Bars 0..47)
    // ==========================================

    // Section 1: Ostinato Exposition (Bars 0..7)
    var m1_bar: usize = 0;
    while (m1_bar < 8) : (m1_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m1_bar, .beat = 0.0 }, VOLUME * 0.85);
    }
    for (0..8) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.45), .{ .bar = b, .beat = 2.5 });
    }
    const layer1_only = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
    };
    var m1_vbar: usize = 0;
    while (m1_vbar < 8) : (m1_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m1_vbar, .beat = 0.0 }, layer1_only);
    }
    for (4..8) |b| {
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.22), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.08), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Section 2: Additive Layering (Bars 8..23)
    var m2_bar: usize = 8;
    while (m2_bar < 24) : (m2_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m2_bar, .beat = 0.0 }, VOLUME * 0.85);
    }
    var m2_cbar: usize = 8;
    while (m2_cbar < 24) : (m2_cbar += 2) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m2_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }
    for (8..24) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.60), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.50), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.30), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.12), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }
    const dual_layers = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
        .{ .bar_offset = 1, .string_index = 1, .volume = 0.75, .octaves = 0 },
    };
    var m2_vbar: usize = 8;
    while (m2_vbar < 24) : (m2_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m2_vbar, .beat = 0.0 }, dual_layers);
    }

    // Section 3: Full Tutti Peak (Bars 24..39)
    var m3_bar: usize = 24;
    while (m3_bar < 40) : (m3_bar += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m3_bar, .beat = 0.0 }, VOLUME * 0.85);
    }
    var m3_cbar: usize = 24;
    while (m3_cbar < 40) : (m3_cbar += 2) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m3_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }
    for (24..40) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.65), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.32), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.14), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }
    const tri_layers = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.75 },
        .{ .bar_offset = 1, .string_index = 1, .volume = 0.70, .octaves = 0 },
        .{ .bar_offset = 0, .string_index = 2, .volume = 0.65, .octaves = -1 },
    };
    var m3_vbar: usize = 24;
    while (m3_vbar < 40) : (m3_vbar += 2) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = m3_vbar, .beat = 0.0 }, tri_layers);
    }

    // Section 4: Bridge & Deceleration into Part 2 (Bars 40..47)
    var m4_b: usize = 40;
    while (m4_b < 48) : (m4_b += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m4_b, .beat = 0.0 }, VOLUME * 0.70);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m4_b, .beat = 0.0 }, VOLUME * 0.50);
    }
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 40, .beat = 0.0 }, layer1_only);
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 44, .beat = 0.0 }, layer1_only);

    // ========================================================
    // PART 2: BOSSA NOVA SYNCOPATED GROOVE (Bars 48..79)
    // ==========================================
    var p2_b: usize = 48;
    while (p2_b < 80) : (p2_b += 2) {
        // Wood bass with syncopated Bossa feel (root on 0.0 and 2.5)
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = p2_b, .beat = 0.0 }, VOLUME * 0.85);

        // Rhodes jazz chord comping
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = p2_b, .beat = 0.0 }, VOLUME * 0.75);

        // Syncopated Latin Bossa rhythm section
        // Bar 0: Kick on 0.0 and 1.5 and 3.0
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.60), .{ .bar = p2_b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = p2_b, .beat = 1.5 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.50), .{ .bar = p2_b, .beat = 3.0 });

        // Bar 1: Kick on 0.0 and 2.0
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.60), .{ .bar = p2_b + 1, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = p2_b + 1, .beat = 2.0 });

        // Crisp Latin syncopated hi-hat across both bars
        for (0..2) |bar_sub| {
            const b = p2_b + bar_sub;
            const hat_beats = [_]f64{ 0.0, 0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5 };
            for (hat_beats) |hbeat| {
                const is_accent = (hbeat == 0.5 or hbeat == 2.0 or hbeat == 3.5);
                const vol = if (is_accent) VOLUME * 0.32 else VOLUME * 0.15;
                try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, vol), .{ .bar = b, .beat = hbeat });
            }
        }

        // Interlocking melodic dialogue
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = p2_b, .beat = 0.0 }, dual_layers);
    }

    // ==========================================
    // FINAL CODA & DISSOLUTION (Bars 80..95)
    // ==========================================
    // Bars 80..87 (4 cycles of 2 bars, gently diminishing)
    var c_b: usize = 80;
    while (c_b < 88) : (c_b += 2) {
        const decay_fac: T = if (c_b < 84) 0.75 else 0.55;
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = c_b, .beat = 0.0 }, VOLUME * decay_fac);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = c_b, .beat = 0.0 }, VOLUME * decay_fac);
    }
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 80, .beat = 0.0 }, layer1_only);
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 84, .beat = 0.0 }, layer1_only);

    // Bars 88..95 (8 bars): Sustaining CM7 harmonic tail on Rhodes and Bass with warm decay
    const coda_len: usize = 8 * 4 * spb_val;
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
        try seq.addInstrument(rhodes_chords, str_idx, chord_wave, .{ .bar = 88, .beat = 0.0 });
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
    try seq.add(bass_track, bass_coda_wave, .{ .bar = 88, .beat = 0.0 });

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

    // Verify 96-bar length (384 beats @ 75 BPM = 13,547,520 frames * 2 channels = 27,095,040 samples)
    try std.testing.expectEqual(@as(usize, 13547520 * 2), wave.samples.len);

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
