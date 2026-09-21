//! Multi-voice contrapuntal canon phrase staggering and voice offsetting utilities.

const std = @import("std");
const lightmix = @import("lightmix");
const Position = @import("position.zig");
const Track = @import("track.zig").inner;
const Instrument = @import("instrument.zig").inner;
const Sequencer = @import("sequencer.zig").inner;
const utils = @import("../root.zig");

/// Configuration for a canon voice entry specifying position offset, pitch transposition, and routing.
pub fn VoiceConfig(comptime T: type) type {
    return struct {
        /// Bar delay offset relative to canon start position.
        bar_offset: usize = 0,
        /// Beat delay offset relative to canon start position.
        beat_offset: f64 = 0.0,
        /// Transposition offset in semitones.
        semitones: isize = 0,
        /// Transposition offset in octaves.
        octaves: isize = 0,
        /// Target instrument string index (for multi-string instruments).
        string_index: usize = 0,
        /// Volume scale factor for this voice.
        volume: T = 1.0,

        const Self = @This();

        /// Returns total semitones of transposition combining semitones and octaves.
        pub fn totalSemitones(self: Self) isize {
            return self.semitones + (self.octaves * 12);
        }

        /// Returns whether two voice configurations are equal, comparing floating-point fields within 1e-6.
        pub fn eql(a: Self, b: Self) bool {
            return a.bar_offset == b.bar_offset and
                @abs(a.beat_offset - b.beat_offset) < 1e-6 and
                a.semitones == b.semitones and
                a.octaves == b.octaves and
                a.string_index == b.string_index and
                @abs(a.volume - b.volume) < 1e-6;
        }

        /// Returns whether two voice lists have the same length and pairwise-equal voices.
        pub fn eqlAll(a: []const Self, b: []const Self) bool {
            if (a.len != b.len) return false;
            for (a, b) |va, vb| {
                if (!va.eql(vb)) return false;
            }
            return true;
        }

        /// Computes the offset position given a base position.
        pub fn offsetPosition(self: Self, base: Position) Position {
            return .{
                .bar = base.bar + self.bar_offset,
                .beat = base.beat + self.beat_offset,
            };
        }
    };
}

/// Calculates the staggered position for voice `voice_index` using fixed bar and beat intervals.
pub fn calculatePosition(base: Position, voice_index: usize, bar_stagger: usize, beat_stagger: f64) Position {
    const idx_f: f64 = @floatFromInt(voice_index);
    return .{
        .bar = base.bar + (voice_index * bar_stagger),
        .beat = base.beat + (idx_f * beat_stagger),
    };
}

/// Calculates net semitone transposition from semitones and octaves.
pub fn calculateTransposition(semitones: isize, octaves: isize) isize {
    return semitones + (octaves * 12);
}

/// Dynamically creates a sequence of uniform staggered voice configurations.
pub fn makeStaggeredVoices(
    comptime T: type,
    allocator: std.mem.Allocator,
    count: usize,
    bar_stagger: usize,
    beat_stagger: f64,
    semitone_stagger: isize,
    octave_stagger: isize,
) ![]VoiceConfig(T) {
    var configs = try allocator.alloc(VoiceConfig(T), count);
    for (0..count) |i| {
        const idx_i: isize = @intCast(i);
        configs[i] = .{
            .bar_offset = i * bar_stagger,
            .beat_offset = @as(f64, @floatFromInt(i)) * beat_stagger,
            .semitones = idx_i * semitone_stagger,
            .octaves = idx_i * octave_stagger,
            .string_index = i,
        };
    }
    return configs;
}

/// Schedules a multi-voice contrapuntal canon phrase onto an instrument across multiple staggered voices.
pub fn scheduleCanon(
    comptime T: type,
    comptime N: type,
    comptime G: type,
    comptime S: type,
    phrase_inst: utils.phrase.Phrase(T, N),
    seq: *Sequencer(T),
    instrument: Instrument(T),
    start_position: Position,
    voices: []const VoiceConfig(T),
) !void {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(seq.bpm, seq.sample_rate));

    for (voices) |voice| {
        const voice_pos = voice.offsetPosition(start_position);
        const net_semitones = voice.totalSemitones();

        for (phrase_inst.notes) |item| {
            const pos = Position{
                .bar = item.bar + voice_pos.bar,
                .beat = item.beat + voice_pos.beat,
            };
            const note_val = if (@hasDecl(N, "add")) item.note.add(net_semitones) else item.note;
            const freq = @as(T, @floatCast(S.gen(note_val)));
            const length: usize = @intFromFloat(spb_val * item.duration_beats);
            const note_wave = try G.gen(
                T,
                seq.allocator,
                freq,
                seq.sample_rate,
                seq.channels,
                length,
                item.volume * voice.volume,
                .{},
            );
            const string_count = instrument.stringCount();
            const string_idx = if (string_count > 0) (item.string + voice.string_index) % string_count else 0;
            try seq.addInstrument(instrument, string_idx, note_wave, pos);
        }
    }
}

/// Schedules a multi-voice contrapuntal canon phrase onto a target track across multiple staggered voices.
pub fn scheduleCanonOnTrack(
    comptime T: type,
    comptime N: type,
    comptime G: type,
    comptime S: type,
    phrase_inst: utils.phrase.Phrase(T, N),
    seq: *Sequencer(T),
    target_track: *Track(T),
    start_position: Position,
    voices: []const VoiceConfig(T),
) !void {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(seq.bpm, seq.sample_rate));

    for (voices) |voice| {
        const voice_pos = voice.offsetPosition(start_position);
        const net_semitones = voice.totalSemitones();

        for (phrase_inst.notes) |item| {
            const pos = Position{
                .bar = item.bar + voice_pos.bar,
                .beat = item.beat + voice_pos.beat,
            };
            const note_val = if (@hasDecl(N, "add")) item.note.add(net_semitones) else item.note;
            const freq = @as(T, @floatCast(S.gen(note_val)));
            const length: usize = @intFromFloat(spb_val * item.duration_beats);
            const note_wave = try G.gen(
                T,
                seq.allocator,
                freq,
                seq.sample_rate,
                seq.channels,
                length,
                item.volume * voice.volume,
                .{},
            );
            try seq.add(target_track, note_wave, pos);
        }
    }
}

test "Stagger calculatePosition offsets bar and beat correctly" {
    const base = Position{ .bar = 1, .beat = 0.5 };

    const pos0 = calculatePosition(base, 0, 2, 1.0);
    try std.testing.expectEqual(@as(usize, 1), pos0.bar);
    try std.testing.expectEqual(@as(f64, 0.5), pos0.beat);

    const pos1 = calculatePosition(base, 1, 2, 1.0);
    try std.testing.expectEqual(@as(usize, 3), pos1.bar);
    try std.testing.expectEqual(@as(f64, 1.5), pos1.beat);

    const pos2 = calculatePosition(base, 2, 2, 1.0);
    try std.testing.expectEqual(@as(usize, 5), pos2.bar);
    try std.testing.expectEqual(@as(f64, 2.5), pos2.beat);
}

test "Stagger calculateTransposition and VoiceConfig" {
    const vc = VoiceConfig(f64){
        .bar_offset = 4,
        .beat_offset = 1.5,
        .semitones = 7,
        .octaves = -1,
        .volume = 0.8,
    };

    try std.testing.expectEqual(@as(isize, -5), vc.totalSemitones());
    try std.testing.expectEqual(@as(isize, 19), calculateTransposition(7, 1));

    const base = Position{ .bar = 2, .beat = 0.5 };
    const offset_pos = vc.offsetPosition(base);
    try std.testing.expectEqual(@as(usize, 6), offset_pos.bar);
    try std.testing.expectEqual(@as(f64, 2.0), offset_pos.beat);
}

test "Stagger makeStaggeredVoices allocates correct configuration" {
    const allocator = std.testing.allocator;

    const voices = try makeStaggeredVoices(f64, allocator, 3, 2, 0.5, 7, -1);
    defer allocator.free(voices);

    try std.testing.expectEqual(@as(usize, 3), voices.len);

    try std.testing.expectEqual(@as(usize, 0), voices[0].bar_offset);
    try std.testing.expectEqual(@as(f64, 0.0), voices[0].beat_offset);
    try std.testing.expectEqual(@as(isize, 0), voices[0].semitones);
    try std.testing.expectEqual(@as(isize, 0), voices[0].octaves);

    try std.testing.expectEqual(@as(usize, 2), voices[1].bar_offset);
    try std.testing.expectEqual(@as(f64, 0.5), voices[1].beat_offset);
    try std.testing.expectEqual(@as(isize, 7), voices[1].semitones);
    try std.testing.expectEqual(@as(isize, -1), voices[1].octaves);

    try std.testing.expectEqual(@as(usize, 4), voices[2].bar_offset);
    try std.testing.expectEqual(@as(f64, 1.0), voices[2].beat_offset);
    try std.testing.expectEqual(@as(isize, 14), voices[2].semitones);
    try std.testing.expectEqual(@as(isize, -2), voices[2].octaves);
}

test "Stagger scheduleCanon schedules staggered canon phrases onto instrument tracks" {
    const allocator = std.testing.allocator;

    const DummySoundGen = struct {
        pub fn gen(
            comptime F: type,
            alloc: std.mem.Allocator,
            freq: F,
            sample_rate: u32,
            channels: u16,
            samples_len: usize,
            volume: F,
            options: anytype,
        ) !lightmix.Wave(F) {
            _ = freq;
            _ = options;
            const samples = try alloc.alloc(F, samples_len * channels);
            @memset(samples, volume);
            return lightmix.Wave(F){
                .allocator = alloc,
                .sample_rate = sample_rate,
                .channels = channels,
                .samples = samples,
            };
        }
    };

    const DummyScaleNote = struct {
        midi: isize,

        pub fn add(self: @This(), semitones: isize) @This() {
            return .{ .midi = self.midi + semitones };
        }
    };

    const DummyScale = struct {
        pub fn gen(note: DummyScaleNote) f64 {
            const exp: f64 = @floatFromInt(note.midi - 69);
            return 440.0 * std.math.pow(f64, 2.0, exp / 12.0);
        }
    };

    const phrase_inst = utils.phrase.Phrase(f64, DummyScaleNote){
        .name = "CanonTheme",
        .notes = &[_]utils.phrase.Phrase(f64, DummyScaleNote).RawNote{
            .{ .bar = 0, .beat = 0.0, .note = .{ .midi = 60 }, .duration_beats = 1.0, .string = 0 },
            .{ .bar = 0, .beat = 1.0, .note = .{ .midi = 64 }, .duration_beats = 1.0, .string = 0 },
        },
    };

    var seq = Sequencer(f64).init(allocator, 120, .{}, 44100, 1);
    defer seq.deinit();

    var instrument = try seq.createInstrument("Violins", 2);
    defer instrument.deinit(allocator);

    const voices = &[_]VoiceConfig(f64){
        .{ .bar_offset = 0, .string_index = 0, .semitones = 0 },
        .{ .bar_offset = 2, .string_index = 1, .semitones = 7 },
    };

    try scheduleCanon(f64, DummyScaleNote, DummySoundGen, DummyScale, phrase_inst, &seq, instrument, .{ .bar = 0, .beat = 0.0 }, voices);

    const tr0 = try seq.getInstrumentTrack(instrument, 0);
    const tr1 = try seq.getInstrumentTrack(instrument, 1);

    try std.testing.expectEqual(@as(usize, 2), tr0.events.items.len);
    try std.testing.expectEqual(@as(usize, 2), tr1.events.items.len);

    // Leader voice on string 0 at bar 0
    try std.testing.expectEqual(@as(usize, 0), tr0.events.items[0].position.bar);
    try std.testing.expectEqual(@as(f64, 0.0), tr0.events.items[0].position.beat);

    // Follower voice on string 1 at bar 2
    try std.testing.expectEqual(@as(usize, 2), tr1.events.items[0].position.bar);
    try std.testing.expectEqual(@as(f64, 0.0), tr1.events.items[0].position.beat);
}

test "Stagger scheduleCanonOnTrack schedules staggered canon phrases onto single track" {
    const allocator = std.testing.allocator;

    const DummySoundGen = struct {
        pub fn gen(
            comptime F: type,
            alloc: std.mem.Allocator,
            freq: F,
            sample_rate: u32,
            channels: u16,
            samples_len: usize,
            volume: F,
            options: anytype,
        ) !lightmix.Wave(F) {
            _ = freq;
            _ = options;
            const samples = try alloc.alloc(F, samples_len * channels);
            @memset(samples, volume);
            return lightmix.Wave(F){
                .allocator = alloc,
                .sample_rate = sample_rate,
                .channels = channels,
                .samples = samples,
            };
        }
    };

    const DummyScaleNote = struct {
        midi: isize,

        pub fn add(self: @This(), semitones: isize) @This() {
            return .{ .midi = self.midi + semitones };
        }
    };

    const DummyScale = struct {
        pub fn gen(note: DummyScaleNote) f64 {
            return @floatFromInt(note.midi);
        }
    };

    const phrase_inst = utils.phrase.Phrase(f64, DummyScaleNote){
        .name = "CanonTheme",
        .notes = &[_]utils.phrase.Phrase(f64, DummyScaleNote).RawNote{
            .{ .bar = 0, .beat = 0.0, .note = .{ .midi = 60 }, .duration_beats = 1.0 },
        },
    };

    var seq = Sequencer(f64).init(allocator, 120, .{}, 44100, 1);
    defer seq.deinit();

    const track_ptr = try seq.createTrack("CanonTrack");

    const voices = &[_]VoiceConfig(f64){
        .{ .bar_offset = 0, .semitones = 0 },
        .{ .bar_offset = 4, .semitones = 12 },
    };

    try scheduleCanonOnTrack(f64, DummyScaleNote, DummySoundGen, DummyScale, phrase_inst, &seq, track_ptr, .{ .bar = 1, .beat = 0.0 }, voices);

    try std.testing.expectEqual(@as(usize, 2), track_ptr.events.items.len);
    try std.testing.expectEqual(@as(usize, 1), track_ptr.events.items[0].position.bar);
    try std.testing.expectEqual(@as(usize, 5), track_ptr.events.items[1].position.bar);
}

test {
    std.testing.refAllDecls(@This());
}
