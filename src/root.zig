//! Main entry point for coffee-chan music composition and deterministic generation.
//!
//! Architectural Overview:
//! 1. Composition Setup: Instantiates a central `Sequencer(f64)` configured for 75 BPM,
//!    44.1 kHz sample rate, and 2-channel stereo output spanning a 96-bar Canon Form arrangement:
//!    - Movement I: Prelude & Theme Entry (Bars 0..15 - 16 bars): Continuous analog vinyl crackle,
//!      FM wood bass ground progression (Phrase 0007), soft low-pass kick drum, and Voice 1 (Leader)
//!      introducing the main canon theme motif (Phrase 0005).
//!    - Movement II: Dual Canon Staggering (Bars 16..47 - 32 bars): Voice 2 (Follower 1) enters
//!      with a 2-bar canon offset, while Rhodes electric piano chord comping (Phrase 0006) and
//!      swing hi-hat join the rhythm section.
//!    - Movement III: Tripartite Canon Climax (Bars 48..79 - 32 bars): Voice 3 (Follower 2) enters
//!      with a 4-bar offset completing 3-part polyphonic counterpoint over full Lo-Fi rhythm and
//!      rich chord textures.
//!    - Movement IV: Coda & Canon Resolution (Bars 80..95 - 16 bars): Voices resolve and exit
//!      sequentially in canon order (Voice 1 -> Voice 2 -> Voice 3), drums drop out, concluding
//!      with a sustaining CM7 harmonic tail and fading vinyl crackle.
//! 2. Subsystem Integration: Registers individual tracks ("VinylNoise", "Bass", "Kick", "HiHat")
//!    and multi-voice instruments ("RhodesChords", "CanonVoices") streaming declarative phrases
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
/// Renders a complete 96-bar Canon Form arrangement at 75 BPM (~5 minutes)
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

    var canon_voices = try seq.createInstrument("CanonVoices", 3);
    defer canon_voices.deinit(allocator);

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

    // 2. Movement I: Prelude & Theme Entry (Bars 0..15 - 16 bars / 64 beats)
    // Ground Bass (Phrase 0007: 8 bars x 2 repetitions)
    try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = 0, .beat = 0.0 }, VOLUME * 0.85);
    try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = 8, .beat = 0.0 }, VOLUME * 0.85);

    // Soft low-pass kick on beats 0.0 and 2.5
    for (0..16) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.45), .{ .bar = b, .beat = 2.5 });
    }

    // Voice 1 (Leader) introduces the main canon theme (Phrase 0005: 8 bars x 2 repetitions)
    const voice1_only = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
    };
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, canon_voices, .{ .bar = 0, .beat = 0.0 }, voice1_only);
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, canon_voices, .{ .bar = 8, .beat = 0.0 }, voice1_only);

    // 3. Movement II: Dual Canon Staggering (Bars 16..47 - 32 bars / 128 beats)
    // Ground Bass across 4 cycles of 8 bars
    var m2_bar: usize = 16;
    while (m2_bar < 48) : (m2_bar += 8) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m2_bar, .beat = 0.0 }, VOLUME * 0.85);
    }

    // Rhodes chord comping (Phrase 0006: 4 bars x 8 repetitions)
    var m2_cbar: usize = 16;
    while (m2_cbar < 48) : (m2_cbar += 4) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m2_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }

    // Drums: Kick on beats 0.0 and 2.5, Swing Hi-Hat on each beat (0.00 accent, 0.75 ghost)
    for (16..48) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.60), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.50), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.30), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.12), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Dual Canon: Voice 1 (string 0) and Voice 2 (string 1, 2-bar offset)
    const dual_voices = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
        .{ .bar_offset = 2, .string_index = 1, .volume = 0.75, .octaves = 0 },
    };
    var m2_vbar: usize = 16;
    while (m2_vbar < 48) : (m2_vbar += 8) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, canon_voices, .{ .bar = m2_vbar, .beat = 0.0 }, dual_voices);
    }

    // 4. Movement III: Tripartite Canon Climax (Bars 48..79 - 32 bars / 128 beats)
    // Ground Bass across 4 cycles of 8 bars
    var m3_bar: usize = 48;
    while (m3_bar < 80) : (m3_bar += 8) {
        try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = m3_bar, .beat = 0.0 }, VOLUME * 0.85);
    }

    // Rhodes chord comping (Phrase 0006: 4 bars x 8 repetitions)
    var m3_cbar: usize = 48;
    while (m3_cbar < 80) : (m3_cbar += 4) {
        try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = m3_cbar, .beat = 0.0 }, VOLUME * 0.70);
    }

    // Full rhythm section: Kick and Swing Hi-Hat
    for (48..80) |b| {
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.65), .{ .bar = b, .beat = 0.0 });
        try seq.add(kick_track, try createKickWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.55), .{ .bar = b, .beat = 2.5 });
        for (0..4) |beat_idx| {
            const beat_f: f64 = @floatFromInt(beat_idx);
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.32), .{ .bar = b, .beat = beat_f });
            try seq.add(hihat_track, try createHiHatWave(allocator, SAMPLE_RATE, CHANNELS, VOLUME * 0.14), .{ .bar = b, .beat = beat_f + 0.75 });
        }
    }

    // Tripartite Canon: Voice 1 (offset 0), Voice 2 (offset 2), Voice 3 (offset 4, octave -1)
    const tri_voices = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.75 },
        .{ .bar_offset = 2, .string_index = 1, .volume = 0.70, .octaves = 0 },
        .{ .bar_offset = 4, .string_index = 2, .volume = 0.65, .octaves = -1 },
    };
    var m3_vbar: usize = 48;
    while (m3_vbar < 80) : (m3_vbar += 8) {
        try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, phrases._0005.phrase_data, &seq, canon_voices, .{ .bar = m3_vbar, .beat = 0.0 }, tri_voices);
    }

    // 5. Movement IV: Coda & Canon Resolution (Bars 80..95 - 16 bars / 64 beats)
    // Ground Bass plays bars 80..87
    try phrases._0007.load(T, synthesizers.wood_bass.WoodBass, utils.scale.Scale, &seq, bass_track, .{ .bar = 80, .beat = 0.0 }, VOLUME * 0.80);

    // Rhodes chord comping plays bars 80..83 and 84..87
    try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = 80, .beat = 0.0 }, VOLUME * 0.60);
    try phrases._0006.loadInstrument(T, synthesizers.rhodes.Rhodes, utils.scale.Scale, &seq, rhodes_chords, .{ .bar = 84, .beat = 0.0 }, VOLUME * 0.55);

    // Voices resolve and exit sequentially in canon order (Voice 1 -> Voice 2 -> Voice 3)
    const coda_subphrase = utils.phrase.Phrase(T, utils.scale.Scale){
        .name = "CanonThemeResolution",
        .notes = phrases._0005.phrase_data.notes[0..8],
    };
    const coda_voices = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.65 },
        .{ .bar_offset = 2, .string_index = 1, .volume = 0.60, .octaves = 0 },
        .{ .bar_offset = 4, .string_index = 2, .volume = 0.55, .octaves = -1 },
    };
    try utils.sequencer.Stagger.scheduleCanon(T, utils.scale.Scale, synthesizers.rhodes.Rhodes, utils.scale.Scale, coda_subphrase, &seq, canon_voices, .{ .bar = 80, .beat = 0.0 }, coda_voices);

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
