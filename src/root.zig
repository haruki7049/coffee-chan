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
const synthesizers = @import("synthesizers");
const utils = @import("utils");
const config = @import("config.zig");
const DrumBank = @import("drum-bank.zig").DrumBank;
const PhraseBank = @import("phrase-bank.zig").PhraseBank;

const T = config.T;
const BPM = config.BPM;
const SAMPLE_RATE = config.SAMPLE_RATE;
const CHANNELS = config.CHANNELS;

const VOLUME: T = 1.0;
const TOTAL_BARS: usize = 96;
const CODA_BAR: usize = 88;

const VoiceConfig = utils.sequencer.Stagger.VoiceConfig(T);

// Layer 1 introduces the primary cafe jazz theme (Phrase 0005)
const layer1_only = [_]VoiceConfig{
    .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
};

// Layer 1 (string 0) and Layer 2 (string 1, 1-bar phased offset)
const dual_layers = [_]VoiceConfig{
    .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
    .{ .bar_offset = 1, .string_index = 1, .volume = 0.75, .octaves = 0 },
};

// Full 3-layer Tutti: Layer 1 (offset 0), Layer 2 (offset 1), Layer 3 (offset 0, octave -1)
const tri_layers = [_]VoiceConfig{
    .{ .bar_offset = 0, .string_index = 0, .volume = 0.75 },
    .{ .bar_offset = 1, .string_index = 1, .volume = 0.70, .octaves = 0 },
    .{ .bar_offset = 0, .string_index = 2, .volume = 0.65, .octaves = -1 },
};

/// One minimal-arpeggio layer scheduled on every 2-bar cycle.
const ArpeggioLayer = struct {
    volume: T,
    accent_interval: usize,
    octave_offset: isize,
};

/// Tracks, instruments and sample banks shared by the composition sections.
const Composition = struct {
    seq: *utils.sequencer.Sequencer(T),
    bass_track: *utils.sequencer.Track(T),
    kick_track: *utils.sequencer.Track(T),
    hihat_track: *utils.sequencer.Track(T),
    arpeggio_track: *utils.sequencer.Track(T),
    rhodes_chords: utils.sequencer.Instrument(T),
    theme_layers: utils.sequencer.Instrument(T),
    drum_bank: *DrumBank,
    phrase_bank: *PhraseBank,

    /// II-V-I ground bass ostinato (Phrase 0007), one 2-bar cycle at a time over `start..end`.
    fn bass(self: Composition, start: usize, end: usize, volume: T) !void {
        var bar = start;
        while (bar < end) : (bar += 2) {
            try self.phrase_bank.loadWoodBass(self.seq, self.bass_track, .{ .bar = bar, .beat = 0.0 }, VOLUME * volume);
        }
    }

    /// Rhodes jazz chord comping (Phrase 0006), one 2-bar cycle at a time over `start..end`.
    fn chords(self: Composition, start: usize, end: usize, volume: T) !void {
        var bar = start;
        while (bar < end) : (bar += 2) {
            try self.phrase_bank.loadRhodesChords(self.seq, self.rhodes_chords, .{ .bar = bar, .beat = 0.0 }, VOLUME * volume);
        }
    }

    /// Melodic canon (Phrase 0005) starting once at `bar`.
    fn canon(self: Composition, bar: usize, voices: []const VoiceConfig) !void {
        try self.phrase_bank.scheduleRhodesCanon(self.seq, self.theme_layers, .{ .bar = bar, .beat = 0.0 }, voices);
    }

    /// Melodic canon repeated every 2 bars over `start..end`.
    fn canonCycles(self: Composition, start: usize, end: usize, voices: []const VoiceConfig) !void {
        var bar = start;
        while (bar < end) : (bar += 2) {
            try self.canon(bar, voices);
        }
    }

    /// Minimal arpeggio layers, all scheduled on each 2-bar cycle over `start..end`.
    fn arpeggios(self: Composition, start: usize, end: usize, layers: []const ArpeggioLayer) !void {
        var bar = start;
        while (bar < end) : (bar += 2) {
            for (layers) |layer| {
                try self.phrase_bank.loadMinimalArpeggio(
                    self.seq,
                    self.arpeggio_track,
                    bar,
                    VOLUME * layer.volume,
                    layer.accent_interval,
                    layer.octave_offset,
                );
            }
        }
    }

    /// Kick on beats 0.0 and 2.5 of every bar in `start..end`.
    fn kicks(self: Composition, start: usize, end: usize, first: T, second: T) !void {
        for (start..end) |bar| {
            try self.seq.add(self.kick_track, try self.drum_bank.getKick(VOLUME * first), .{ .bar = bar, .beat = 0.0 });
            try self.seq.add(self.kick_track, try self.drum_bank.getKick(VOLUME * second), .{ .bar = bar, .beat = 2.5 });
        }
    }

    /// Swing hi-hat on each beat of every bar in `start..end` (accent on the beat, ghost at +0.75).
    fn hihats(self: Composition, start: usize, end: usize, accent: T, ghost: T) !void {
        for (start..end) |bar| {
            for (0..4) |beat_idx| {
                const beat: f64 = @floatFromInt(beat_idx);
                try self.seq.add(self.hihat_track, try self.drum_bank.getHiHat(VOLUME * accent), .{ .bar = bar, .beat = beat });
                try self.seq.add(self.hihat_track, try self.drum_bank.getHiHat(VOLUME * ghost), .{ .bar = bar, .beat = beat + 0.75 });
            }
        }
    }

    /// Kick and swing hi-hat rhythm section over `start..end`.
    fn drums(self: Composition, start: usize, end: usize, kick: [2]T, hihat: [2]T) !void {
        try self.kicks(start, end, kick[0], kick[1]);
        try self.hihats(start, end, hihat[0], hihat[1]);
    }

    /// Movement I: Ostinato Exposition (Bars 0..7).
    fn ostinatoExposition(self: Composition) !void {
        try self.bass(0, 8, 0.85);
        try self.kicks(0, 8, 0.55, 0.45);
        try self.canonCycles(0, 8, &layer1_only);
        // Swing hi-hat enters gently at bar 4
        try self.hihats(4, 8, 0.22, 0.08);
    }

    /// Movement II: Additive Process & Phased Layering (Bars 8..23).
    fn additiveProcess(self: Composition) !void {
        try self.bass(8, 24, 0.85);
        try self.chords(8, 24, 0.70);
        try self.drums(8, 24, .{ 0.60, 0.50 }, .{ 0.30, 0.12 });
        try self.canonCycles(8, 24, &dual_layers);
    }

    /// Movement III: Additive Crescendo & Full Tutti (Bars 24..39).
    fn cumulativeDensity(self: Composition) !void {
        try self.bass(24, 40, 0.85);
        try self.chords(24, 40, 0.70);
        try self.drums(24, 40, .{ 0.65, 0.55 }, .{ 0.32, 0.14 });
        try self.canonCycles(24, 40, &tri_layers);
    }

    /// Bridge & Deceleration into Part 2 (Bars 40..47).
    fn bridge(self: Composition) !void {
        try self.bass(40, 48, 0.70);
        try self.chords(40, 48, 0.50);
        try self.canon(40, &layer1_only);
        try self.canon(44, &layer1_only);
    }

    /// Part 2, Phase 1: minimal 16th-note arpeggio with 3:4 polymetric accents (Bars 48..63).
    fn arpeggioIntroduction(self: Composition) !void {
        try self.bass(48, 64, 0.85);
        try self.chords(48, 64, 0.50);
        try self.canonCycles(48, 64, &layer1_only);
        try self.arpeggios(48, 64, &.{.{ .volume = 0.28, .accent_interval = 3, .octave_offset = 0 }});
        try self.drums(48, 64, .{ 0.55, 0.45 }, .{ 0.26, 0.10 });
    }

    /// Part 2, Phase 2: dual interlocking arpeggiation tutti (Bars 64..71).
    /// Layer 1 (octave 4, 3-step accents) and Layer 2 (octave 5, 4-step accents).
    fn interlockingArpeggios(self: Composition) !void {
        try self.bass(64, 72, 0.85);
        try self.chords(64, 72, 0.60);
        try self.canonCycles(64, 72, &dual_layers);
        try self.arpeggios(64, 72, &.{
            .{ .volume = 0.24, .accent_interval = 3, .octave_offset = 0 },
            .{ .volume = 0.20, .accent_interval = 4, .octave_offset = 1 },
        });
        try self.drums(64, 72, .{ 0.65, 0.55 }, .{ 0.32, 0.14 });
    }

    /// Part 2, Phase 3: resolution and arpeggio decrescendo (Bars 72..79).
    fn resolution(self: Composition) !void {
        try self.bass(72, 80, 0.80);
        try self.chords(72, 80, 0.55);
        try self.canonCycles(72, 80, &dual_layers);
        try self.arpeggios(72, 80, &.{.{ .volume = 0.16, .accent_interval = 3, .octave_offset = 0 }});
        try self.drums(72, 80, .{ 0.55, 0.45 }, .{ 0.24, 0.10 });
    }

    /// Final coda, wind-down (Bars 80..87): gently diminishing bass, chords and theme.
    fn windDown(self: Composition) !void {
        try self.bass(80, 84, 0.75);
        try self.chords(80, 84, 0.75);
        try self.bass(84, 88, 0.55);
        try self.chords(84, 88, 0.55);
        try self.canon(80, &layer1_only);
        try self.canon(84, &layer1_only);
    }

    /// Final coda, tail (Bars 88..95): sustaining CM7 harmonic tail on Rhodes and bass with warm decay.
    fn harmonicTail(self: Composition) !void {
        const allocator = self.seq.allocator;
        const coda_len: usize = (TOTAL_BARS - CODA_BAR) * 4 * utils.tempo.spb(BPM, SAMPLE_RATE);
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
            try self.seq.addInstrument(self.rhodes_chords, str_idx, chord_wave, .{ .bar = CODA_BAR, .beat = 0.0 });
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
        try self.seq.add(self.bass_track, bass_coda_wave, .{ .bar = CODA_BAR, .beat = 0.0 });
    }
};

/// Continuous vinyl crackle across all bars, fading out during the final 8 bars.
fn vinylNoise(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const spb_val = utils.tempo.spb(BPM, SAMPLE_RATE);
    const total_samples = TOTAL_BARS * 4 * spb_val;

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
    const fade_start_sample = CODA_BAR * 4 * spb_val;
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
    return .{
        .allocator = allocator,
        .samples = vinyl_samples,
        .sample_rate = SAMPLE_RATE,
        .channels = CHANNELS,
    };
}

/// Main composition pipeline function.
/// Renders a complete 96-bar Minimal Music arrangement at 75 BPM (~5 minutes)
/// followed by peak amplitude normalization.
pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    // Reset pseudo-random generators to guarantee bitwise deterministic output across calls
    synthesizers.vinyl_noise.VinylNoise.reset();
    synthesizers.whitenoise.WhiteNoise.reset();

    const allocator: std.mem.Allocator = init.arena.allocator();

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

    var drum_bank = DrumBank.init(allocator, BPM, SAMPLE_RATE, CHANNELS);
    defer drum_bank.deinit();

    var phrase_bank = PhraseBank.init(allocator, BPM, SAMPLE_RATE, CHANNELS);
    defer phrase_bank.deinit();

    const song = Composition{
        .seq = &seq,
        .bass_track = bass_track,
        .kick_track = kick_track,
        .hihat_track = hihat_track,
        .arpeggio_track = arpeggio_track,
        .rhodes_chords = rhodes_chords,
        .theme_layers = theme_layers,
        .drum_bank = &drum_bank,
        .phrase_bank = &phrase_bank,
    };

    // 2. Arrangement
    try seq.add(vinyl_track, try vinylNoise(allocator), .{ .bar = 0, .beat = 0.0 });

    // Part 1: Initial Minimal Build (Bars 0..47)
    try song.ostinatoExposition();
    try song.additiveProcess();
    try song.cumulativeDensity();
    try song.bridge();

    // Part 2: Polyrhythmic Minimal Arpeggiation (Bars 48..79)
    try song.arpeggioIntroduction();
    try song.interlockingArpeggios();
    try song.resolution();

    // Final coda & dissolution (Bars 80..95)
    try song.windDown();
    try song.harmonicTail();

    // 3. Master & Peak Normalization
    var result: lightmix.Wave(T) = try seq.render();
    try filters.normalize(T, &result, 1.0);
    return result;
}

test "5-minute audio wave integrity and timing" {
    // Full 5-minute song generation and comprehensive audio audit
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
    try std.testing.expectEqual(@as(u32, SAMPLE_RATE), wave.sample_rate);
    try std.testing.expectEqual(@as(u16, CHANNELS), wave.channels);

    // Exact 96 bars (384 beats @ 75 BPM = 13,547,520 frames * 2 channels = 27,095,040 samples)
    const expected_frames: usize = 96 * 4 * utils.tempo.spb(BPM, SAMPLE_RATE);
    try std.testing.expectEqual(@as(usize, 13547520), expected_frames);
    try std.testing.expectEqual(expected_frames * CHANNELS, wave.samples.len);

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
    const samples_per_bar = 4 * utils.tempo.spb(BPM, SAMPLE_RATE) * CHANNELS;
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

test {
    _ = @import("drum-bank.zig");
    _ = @import("phrase-bank.zig");
}
