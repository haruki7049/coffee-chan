const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const utils = @import("utils");

const T = f64;

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 120;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var seq = utils.sequencer.Sequencer(T).init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    var phrase_0000 = try phrases._0000.gen(T, synthesizers.sine.Sine, utils.scale.Scale, allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    defer phrase_0000.deinit();

    var phrase_0002 = try phrases._0002.gen(T, synthesizers.karplus_strong.KarplusStrong, utils.scale.Scale, allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    defer phrase_0002.deinit();

    const main_track = try seq.createTrack("Main Track");
    try seq.addWave(main_track, phrase_0002, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(main_track, phrase_0000, .{ .bar = 1, .beat = 0.0 });

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
}
