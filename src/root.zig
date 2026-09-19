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
//!    - Part 2: Polyrhythmic Minimal Arpeggiation Development (Bars 48..95 - 48 bars):
//!      - Bars 48..63 (16 bars): Continuous 16th-note Rhodes minimal arpeggiation with a 3:4 polymetric
//!        accent grouping over the hypnotic Dm9 -> G13 -> CM7 ostinato.
//!      - Bars 64..71 (8 bars): Dual interlocking polyrhythmic arpeggio layers (octaves 4 & 5) dancing
//!        against full 2-layer melodic canon and driving Lo-Fi rhythm.
//!      - Bars 72..79 (8 bars): Harmonic resolution and gradual arpeggio dissolution.
//!      - Bars 80..87: Progressive phrase wind-down and rhythmic decrescendo.
//!      - Bars 88..95: Sustaining CM7 harmonic tail on Rhodes and Bass with warm exponential decay,
//!        while vinyl crackle gently fades into silence at bar 96 (~5 minutes).
//! 2. Subsystem Integration: Registers individual tracks ("VinylNoise", "Bass", "Kick", "HiHat", "Arpeggio")
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

fn addMinimalArpeggio(
    allocator: std.mem.Allocator,
    sample_rate: u32,
    channels: u16,
    spb_val: usize,
    seq: *utils.sequencer.Sequencer(T),
    target_track: *utils.sequencer.Track(T),
    start_bar: usize,
    volume: T,
    accent_interval: usize,
    octave_offset: isize,
) !void {
    const spb_f: f64 = @floatFromInt(spb_val);
    const note_len: usize = @intFromFloat(spb_f * 0.35);

    const pattern_notes = [_]utils.scale.Scale{
        // Bar 0: Dm9 (beats 0.0 .. 2.0)
        .{ .code = .d, .octave = 4 },
        .{ .code = .f, .octave = 4 },
        .{ .code = .a, .octave = 4 },
        .{ .code = .c, .octave = 5 },
        .{ .code = .e, .octave = 5 },
        .{ .code = .c, .octave = 5 },
        .{ .code = .a, .octave = 4 },
        .{ .code = .f, .octave = 4 },
        // Bar 0: G13 (beats 2.0 .. 4.0)
        .{ .code = .d, .octave = 4 },
        .{ .code = .g, .octave = 4 },
        .{ .code = .b, .octave = 4 },
        .{ .code = .d, .octave = 5 },
        .{ .code = .e, .octave = 5 },
        .{ .code = .f, .octave = 5 },
        .{ .code = .d, .octave = 5 },
        .{ .code = .b, .octave = 4 },
        // Bar 1: CM7 (beats 0.0 .. 4.0)
        .{ .code = .c, .octave = 4 },
        .{ .code = .e, .octave = 4 },
        .{ .code = .g, .octave = 4 },
        .{ .code = .b, .octave = 4 },
        .{ .code = .c, .octave = 5 },
        .{ .code = .e, .octave = 5 },
        .{ .code = .g, .octave = 5 },
        .{ .code = .e, .octave = 5 },
        .{ .code = .c, .octave = 5 },
        .{ .code = .b, .octave = 4 },
        .{ .code = .g, .octave = 4 },
        .{ .code = .e, .octave = 4 },
        .{ .code = .g, .octave = 4 },
        .{ .code = .b, .octave = 4 },
        .{ .code = .d, .octave = 5 },
        .{ .code = .b, .octave = 4 },
    };

    for (pattern_notes, 0..) |base_note, idx| {
        const note = base_note.add(octave_offset * 12);
        const bar_offset = idx / 16;
        const beat_in_bar = @as(f64, @floatFromInt(idx % 16)) * 0.25;
        const is_accent = (idx % accent_interval == 0);
        const note_vol = if (is_accent) volume * 1.35 else volume * 0.85;

        var wave = try synthesizers.rhodes.Rhodes.gen(
            T,
            allocator,
            note.gen(),
            sample_rate,
            channels,
            note_len,
            note_vol,
            .{ .decay_rate = 7.0 },
        );
        try filters.decay(T, &wave);
        try seq.add(target_track, wave, .{
            .bar = start_bar + bar_offset,
            .beat = beat_in_bar,
        });
    }
}

/// Main composition pipeline function.
/// Renders a complete 96-bar Minimal Music arrangement at 75 BPM (~5 minutes)
/// followed by peak amplitude normalization.
pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    // Reset pseudo-random generators to guarantee bitwise deterministic output across calls
    synthesizers.vinyl_noise.VinylNoise.reset();
    synthesizers.whitenoise.WhiteNoise.reset();

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

    const arpeggio_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("Arpeggio");

    // Fetch pointers after all creations to avoid array reallocation invalidation
    const vinyl_track = &seq.tracks.items[vinyl_track_idx];
    const bass_track = &seq.tracks.items[bass_track_idx];
    const kick_track = &seq.tracks.items[kick_track_idx];
    const hihat_track = &seq.tracks.items[hihat_track_idx];
    const arpeggio_track = &seq.tracks.items[arpeggio_track_idx];

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

    // Section 4: Bridge & Deceleration into Part 2 (Bars 40..47)
    var m4_b: usize = 40;
    while (m4_b < 48) : (m4_b += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m4_b, .beat = 0.0 }, VOLUME * 0.70);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m4_b, .beat = 0.0 }, VOLUME * 0.50);
    }
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 40, .beat = 0.0 }, layer1_only);
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = 44, .beat = 0.0 }, layer1_only);

    // ========================================================
    // PART 2: POLYRHYTHMIC MINIMAL ARPEGGIATION (Bars 48..79)
    // ========================================================
    // Phase 1: Minimal 16th-note arpeggio introduction with 3:4 polymetric accents (Bars 48..63 - 16 bars)
    var p2_b1: usize = 48;
    while (p2_b1 < 64) : (p2_b1 += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = p2_b1, .beat = 0.0 }, VOLUME * 0.85);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = p2_b1, .beat = 0.0 }, VOLUME * 0.50);
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = p2_b1, .beat = 0.0 }, layer1_only);
        try addMinimalArpeggio(allocator, SAMPLE_RATE, CHANNELS, spb_val, &seq, arpeggio_track, p2_b1, VOLUME * 0.28, 3, 0);
    }
    for (48..64) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.45), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.26), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.10), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Phase 2: Dual interlocking arpeggiation tutti (Bars 64..71 - 8 bars)
    // Layer 1 (mid-octave 4, 3-step polymetric accents) + Layer 2 (high-octave 5, 4-step accents)
    var p2_b2: usize = 64;
    while (p2_b2 < 72) : (p2_b2 += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = p2_b2, .beat = 0.0 }, VOLUME * 0.85);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = p2_b2, .beat = 0.0 }, VOLUME * 0.60);
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = p2_b2, .beat = 0.0 }, dual_layers);
        try addMinimalArpeggio(allocator, SAMPLE_RATE, CHANNELS, spb_val, &seq, arpeggio_track, p2_b2, VOLUME * 0.24, 3, 0);
        try addMinimalArpeggio(allocator, SAMPLE_RATE, CHANNELS, spb_val, &seq, arpeggio_track, p2_b2, VOLUME * 0.20, 4, 1);
    }
    for (64..72) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.65), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.32), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.14), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Phase 3: Resolution & arpeggio decrescendo (Bars 72..79 - 8 bars)
    var p2_b3: usize = 72;
    while (p2_b3 < 80) : (p2_b3 += 2) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = p2_b3, .beat = 0.0 }, VOLUME * 0.80);
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = p2_b3, .beat = 0.0 }, VOLUME * 0.55);
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, theme_layers, .{ .bar = p2_b3, .beat = 0.0 }, dual_layers);
        try addMinimalArpeggio(allocator, SAMPLE_RATE, CHANNELS, spb_val, &seq, arpeggio_track, p2_b3, VOLUME * 0.16, 3, 0);
    }
    for (72..80) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.45), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.24), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.10), .{ .bar = b, .beat = beat_f + 0.75 });
        }
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

test "5-minute audio wave integrity, timing, and loudness headroom" {
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

    // 1. Audio Format and Timing Validation
    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);

    // Exact 96 bars (384 beats @ 75 BPM = 13,547,520 frames * 2 channels = 27,095,040 samples)
    const expected_frames: usize = 96 * 4 * utils.tempo.spb(75, 44100);
    try std.testing.expectEqual(@as(usize, 13547520), expected_frames);
    try std.testing.expectEqual(expected_frames * 2, wave.samples.len);

    // Exact duration verification: 307.2 seconds (~5.12 minutes)
    const duration_secs: f64 = @as(f64, @floatFromInt(expected_frames)) / @as(f64, @floatFromInt(wave.sample_rate));
    try std.testing.expectApproxEqAbs(@as(f64, 307.2), duration_secs, 1e-4);

    // 2. Numerical Integrity and Headroom Validation
    var peak: T = 0.0;
    var sum_sq: f64 = 0.0;
    for (wave.samples) |s| {
        try std.testing.expect(!std.math.isNan(s));
        try std.testing.expect(!std.math.isInf(s));
        try std.testing.expect(s >= -1.0 and s <= 1.0);
        const abs_s = @abs(s);
        if (abs_s > peak) peak = abs_s;
        sum_sq += s * s;
    }

    // Normalized peak must reach full-scale ceiling (1.0) without exceeding bounds
    try std.testing.expectApproxEqAbs(@as(T, 1.0), peak, 1e-4);

    // 3. Loudness & Dynamic Headroom Standards
    // Root-Mean-Square (RMS) power level across the full 5 minutes
    const rms: f64 = std.math.sqrt(sum_sq / @as(f64, @floatFromInt(wave.samples.len)));
    // Cafe jazz ambient minimal aesthetic maintains healthy RMS dynamic range (between -26 dB and -8 dB full-scale)
    try std.testing.expect(rms >= 0.05 and rms <= 0.40);

    // 4. Additive Arrangement Dynamic Contrast Validation
    // Compare initial exposition energy (Bars 0..4) with tutti crescendo peak energy (Bars 64..68)
    const samples_per_bar = 4 * utils.tempo.spb(75, 44100) * 2;
    var intro_sum_sq: f64 = 0.0;
    for (wave.samples[0 .. 4 * samples_per_bar]) |s| {
        intro_sum_sq += s * s;
    }
    const intro_rms = std.math.sqrt(intro_sum_sq / @as(f64, @floatFromInt(4 * samples_per_bar)));

    var tutti_sum_sq: f64 = 0.0;
    const tutti_start = 64 * samples_per_bar;
    for (wave.samples[tutti_start .. tutti_start + 4 * samples_per_bar]) |s| {
        tutti_sum_sq += s * s;
    }
    const tutti_rms = std.math.sqrt(tutti_sum_sq / @as(f64, @floatFromInt(4 * samples_per_bar)));

    // Tutti crescendo section must exhibit greater acoustic density than initial exposition
    try std.testing.expect(tutti_rms > intro_rms);
}

test "5-minute audio wave deterministic output bitwise identity" {
    // Run 1
    var arena1 = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena1.deinit();
    const proc_init1 = std.process.Init{
        .minimal = .{ .environ = undefined, .args = undefined },
        .gpa = std.testing.allocator,
        .arena = &arena1,
        .io = undefined,
        .environ_map = undefined,
        .preopens = undefined,
    };
    var wave1 = try gen(proc_init1);
    defer wave1.deinit();

    // Run 2
    var arena2 = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena2.deinit();
    const proc_init2 = std.process.Init{
        .minimal = .{ .environ = undefined, .args = undefined },
        .gpa = std.testing.allocator,
        .arena = &arena2,
        .io = undefined,
        .environ_map = undefined,
        .preopens = undefined,
    };
    var wave2 = try gen(proc_init2);
    defer wave2.deinit();

    // Validate bitwise sample identity across all 27,095,040 samples
    try std.testing.expectEqual(wave1.samples.len, wave2.samples.len);
    try std.testing.expectEqualSlices(T, wave1.samples, wave2.samples);
}
