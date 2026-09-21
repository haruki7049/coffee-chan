const std = @import("std");
const music = @import("music");
const sequencer = @import("sequencer");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Bind = utils.phrase.Bind;

pub const _0000 = Bind(@import("./0000/phrase.zon"));
pub const _0001 = Bind(@import("./0001/phrase.zon"));
pub const _0002 = Bind(@import("./0002/phrase.zon"));
pub const _0003 = Bind(@import("./0003/phrase.zon"));
pub const _0004 = Bind(@import("./0004/phrase.zon"));
pub const _0005 = Bind(@import("./0005/phrase.zon"));
pub const _0006 = Bind(@import("./0006/phrase.zon"));
pub const _0007 = Bind(@import("./0007/phrase.zon"));

const Sine = synthesizers.sine.Sine;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;

/// Per-phrase test configuration: the synthesizer used to render the phrase and,
/// when set, the instrument used to exercise `loadInstrument`.
const Case = struct {
    name: []const u8,
    P: type,
    G: type,
    instrument: ?struct { name: []const u8, strings: usize },
};

const cases = [_]Case{
    .{ .name = "0000", .P = _0000, .G = Sine, .instrument = .{ .name = "LeadSynth", .strings = 1 } },
    .{ .name = "0001", .P = _0001, .G = KarplusStrong, .instrument = null },
    .{ .name = "0002", .P = _0002, .G = KarplusStrong, .instrument = .{ .name = "AcousticGuitar", .strings = 6 } },
    .{ .name = "0003", .P = _0003, .G = KarplusStrong, .instrument = null },
    .{ .name = "0004", .P = _0004, .G = KarplusStrong, .instrument = .{ .name = "AcousticGuitar", .strings = 6 } },
    .{ .name = "0005", .P = _0005, .G = KarplusStrong, .instrument = .{ .name = "AcousticGuitar", .strings = 6 } },
    .{ .name = "0006", .P = _0006, .G = KarplusStrong, .instrument = .{ .name = "AcousticGuitar", .strings = 6 } },
    .{ .name = "0007", .P = _0007, .G = KarplusStrong, .instrument = .{ .name = "AcousticGuitar", .strings = 6 } },
};

test "gen renders every phrase" {
    const allocator = std.testing.allocator;

    inline for (cases) |c| {
        var wave = try c.P.gen(f64, c.G, music.scale.Scale, allocator, 60, 44100, 2, 1.0);
        defer wave.deinit();

        try std.testing.expect(wave.samples.len > 0);
        try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
        try std.testing.expectEqual(@as(u16, 2), wave.channels);
    }
}

test "loadInstrument renders phrases across instrument strings" {
    const allocator = std.testing.allocator;

    inline for (cases) |c| {
        if (c.instrument) |spec| {
            var seq = sequencer.Sequencer(f64).init(allocator, 120, .{}, 44100, 2);
            defer seq.deinit();

            var inst = try seq.createInstrument(spec.name, spec.strings);
            defer inst.deinit(allocator);

            try c.P.loadInstrument(f64, c.G, music.scale.Scale, &seq, inst, .{}, 1.0);

            var wave = try seq.render();
            defer wave.deinit();

            try std.testing.expect(wave.samples.len > 0);
            try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
            try std.testing.expectEqual(@as(u16, 2), wave.channels);
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
