//! Main entry point for coffee-chan music composition and deterministic generation.
//!
//! Architectural Overview:
//! 1. Composition Setup: Instantiates a central `Sequencer(f64)` configured for 120 BPM,
//!    44.1 kHz sample rate, and 2-channel stereo output.
//! 2. Subsystem Integration: Registers individual tracks ("Guitar", "Melody") and streams
//!    declarative phrases into the sequencer timeline using physical modeling (Karplus-Strong)
//!    and additive (Sine wave) synthesizers.
//! 3. Voice Scheduling & Rendering: Delegates timeline rendering to `VoiceScheduler` (which handles
//!    the Single String Model and equal-power micro-fades) and `Renderer` (sample accumulation).
//! 4. DSP Post-Processing: Applies peak amplitude normalization via `filters.normalize` before
//!    returning the final `lightmix.Wave(f64)` for WAV file output.

const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const utils = @import("utils");

const T = f64;

/// Main composition pipeline function.
/// Initializes the sequencer timeline, loads acoustic guitar and melody phrases with their
/// respective synthesizers, renders the multi-channel sample buffer, and normalizes peak amplitude.
pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 120;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var seq = utils.sequencer.Sequencer(T).init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    const guitar_track = try seq.createTrack("Guitar");
    try phrases._0002.load(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, &seq, guitar_track, .{ .bar = 0, .beat = 0.0 }, VOLUME);

    const melody_track = try seq.createTrack("Melody");
    try phrases._0000.load(T, synthesizers.sine.Sine, utils.scale.Scale, &seq, melody_track, .{ .bar = 1, .beat = 0.0 }, VOLUME);

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
