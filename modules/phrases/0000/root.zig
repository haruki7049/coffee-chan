const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Scale = utils.scale.Scale;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;
const spb = utils.tempo.spb;

const Note = struct {
    code: utils.scale.Code,
    octave: usize,
};

/// 4-bar acoustic guitar arpeggio progression: | Fmaj7 | Em7 | Dm7 | Cmaj7 |
const PROGRESSION = [_]Note{
    // Bar 1: Fmaj7 (F3, C4, A3, E4, C4, A3, E4, C4)
    .{ .code = .f, .octave = 3 },
    .{ .code = .c, .octave = 4 },
    .{ .code = .a, .octave = 3 },
    .{ .code = .e, .octave = 4 },
    .{ .code = .c, .octave = 4 },
    .{ .code = .a, .octave = 3 },
    .{ .code = .e, .octave = 4 },
    .{ .code = .c, .octave = 4 },

    // Bar 2: Em7 (E3, B3, G3, D4, B3, G3, D4, B3)
    .{ .code = .e, .octave = 3 },
    .{ .code = .b, .octave = 3 },
    .{ .code = .g, .octave = 3 },
    .{ .code = .d, .octave = 4 },
    .{ .code = .b, .octave = 3 },
    .{ .code = .g, .octave = 3 },
    .{ .code = .d, .octave = 4 },
    .{ .code = .b, .octave = 3 },

    // Bar 3: Dm7 (D3, A3, F3, C4, A3, F3, C4, A3)
    .{ .code = .d, .octave = 3 },
    .{ .code = .a, .octave = 3 },
    .{ .code = .f, .octave = 3 },
    .{ .code = .c, .octave = 4 },
    .{ .code = .a, .octave = 3 },
    .{ .code = .f, .octave = 3 },
    .{ .code = .c, .octave = 4 },
    .{ .code = .a, .octave = 3 },

    // Bar 4: Cmaj7 (C3, G3, E3, B3, G3, E3, B3, G3)
    .{ .code = .c, .octave = 3 },
    .{ .code = .g, .octave = 3 },
    .{ .code = .e, .octave = 3 },
    .{ .code = .b, .octave = 3 },
    .{ .code = .g, .octave = 3 },
    .{ .code = .e, .octave = 3 },
    .{ .code = .b, .octave = 3 },
    .{ .code = .g, .octave = 3 },
};

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
    var composer = lightmix.Composer(T).init(allocator, .{
        .channels = channels,
        .sample_rate = sample_rate,
    });
    defer composer.deinit();

    const beat_frames = spb(bpm, sample_rate);
    const step_frames = beat_frames / 2; // 8th note interval
    const note_duration = beat_frames; // 1 beat natural decay per pluck

    for (PROGRESSION, 0..) |note, i| {
        const freq: T = Scale.gen(.{ .code = note.code, .octave = note.octave });
        // Emphasize root note on the downbeat of each bar
        const is_root = (i % 8 == 0);
        const note_vol: T = if (is_root) volume * 1.0 else volume * 0.75;

        var pluck = try KarplusStrong.gen(T, allocator, freq, sample_rate, channels, note_duration, note_vol, .{
            .feedback = 0.993,
            .filter_weight = 0.5,
            .excitation_lpf_passes = if (is_root) 2 else 0,
        });
        defer pluck.deinit();

        const start_sample = i * step_frames * channels;
        try composer.append(.{
            .wave = pluck,
            .start_point = start_sample,
        });
    }

    return try composer.finalize(.{});
}

test {
    std.testing.refAllDecls(@This());
}
