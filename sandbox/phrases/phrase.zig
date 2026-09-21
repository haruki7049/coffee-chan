//! Shared sandbox entry for rendering a single phrase with a sine synthesizer.
//!
//! The phrase to render is selected at build time through the `phrase_options`
//! module (see `build_sandbox` in `build.zig`), e.g. `.phrase = "_0000"`.

const std = @import("std");
const lightmix = @import("lightmix");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const utils = @import("utils");
const options = @import("phrase_options");

const T = f64;
const Sine = synthesizers.sine.Sine;
const Scale = utils.scale.Scale;
const Phrase = @field(phrases, options.phrase);

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 90;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    return try Phrase.gen(T, Sine, Scale, allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
}

test "generate sandbox phrase" {
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
}
