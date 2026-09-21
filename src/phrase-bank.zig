//! Cached phrase event templates (wood bass, Rhodes chords/canon, arpeggio) for the composition.

const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const synthesizers = @import("synthesizers");
const music = @import("music");
const utils = @import("utils");
const config = @import("config.zig");

const T = config.T;
const BPM = config.BPM;
const SAMPLE_RATE = config.SAMPLE_RATE;
const CHANNELS = config.CHANNELS;

pub const PhraseBank = struct {
    pub const TrackEvent = struct {
        bar_offset: usize,
        beat_offset: f64,
        wave: lightmix.Wave(T),
    };

    pub const InstrumentEvent = struct {
        string_idx: usize,
        bar_offset: usize,
        beat_offset: f64,
        wave: lightmix.Wave(T),
    };

    const VolumeKey = struct {
        volume: T,

        pub fn eql(a: VolumeKey, b: VolumeKey) bool {
            return @abs(a.volume - b.volume) < 1e-6;
        }
    };

    const RhodesChordKey = struct {
        volume: T,
        // Shapes the synthesized template only; not part of the cache identity.
        string_count: usize,

        pub fn eql(a: RhodesChordKey, b: RhodesChordKey) bool {
            return @abs(a.volume - b.volume) < 1e-6;
        }
    };

    const RhodesCanonKey = struct {
        voices: []const utils.sequencer.Stagger.VoiceConfig(T),
        // Shapes the synthesized template only; not part of the cache identity.
        string_count: usize,

        pub fn eql(a: RhodesCanonKey, b: RhodesCanonKey) bool {
            return utils.sequencer.Stagger.VoiceConfig(T).eqlAll(a.voices, b.voices);
        }

        pub fn dupe(self: RhodesCanonKey, allocator: std.mem.Allocator) !RhodesCanonKey {
            return .{
                .voices = try allocator.dupe(utils.sequencer.Stagger.VoiceConfig(T), self.voices),
                .string_count = self.string_count,
            };
        }

        pub fn deinit(self: RhodesCanonKey, allocator: std.mem.Allocator) void {
            allocator.free(self.voices);
        }
    };

    const ArpeggioKey = struct {
        volume: T,
        accent_interval: usize,
        octave_offset: isize,

        pub fn eql(a: ArpeggioKey, b: ArpeggioKey) bool {
            return @abs(a.volume - b.volume) < 1e-6 and
                a.accent_interval == b.accent_interval and
                a.octave_offset == b.octave_offset;
        }
    };

    const pattern_notes = [_]music.scale.Scale{
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

    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,

    wood_bass: utils.cache.TemplateCache(VolumeKey, TrackEvent) = .{},
    rhodes_chord: utils.cache.TemplateCache(RhodesChordKey, InstrumentEvent) = .{},
    rhodes_canon: utils.cache.TemplateCache(RhodesCanonKey, InstrumentEvent) = .{},
    arpeggio: utils.cache.TemplateCache(ArpeggioKey, TrackEvent) = .{},

    pub fn init(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16) PhraseBank {
        return .{
            .allocator = allocator,
            .bpm = bpm,
            .sample_rate = sample_rate,
            .channels = channels,
        };
    }

    pub fn deinit(self: *PhraseBank) void {
        self.wood_bass.deinit(self.allocator);
        self.rhodes_chord.deinit(self.allocator);
        self.rhodes_canon.deinit(self.allocator);
        self.arpeggio.deinit(self.allocator);
    }

    fn synthWoodBassTemplate(self: *PhraseBank, key: VolumeKey) ![]TrackEvent {
        const volume = key.volume;
        const raw_events = try phrases._0007.toEvents(T, music.scale.Scale, self.allocator, self.bpm, self.sample_rate);
        defer self.allocator.free(raw_events);

        var template_events = try self.allocator.alloc(TrackEvent, raw_events.len);
        var synth_idx: usize = 0;
        errdefer {
            for (template_events[0..synth_idx]) |*ev| {
                ev.wave.deinit();
            }
            self.allocator.free(template_events);
        }

        for (raw_events) |raw| {
            const wave = try synthesizers.wood_bass.WoodBass.gen(
                T,
                self.allocator,
                raw.freq,
                self.sample_rate,
                self.channels,
                raw.length,
                volume * raw.volume,
                .{},
            );
            template_events[synth_idx] = .{
                .bar_offset = raw.position.bar,
                .beat_offset = raw.position.beat,
                .wave = wave,
            };
            synth_idx += 1;
        }

        return template_events;
    }

    fn getOrCreateWoodBassTemplate(self: *PhraseBank, volume: T) ![]const TrackEvent {
        return self.wood_bass.getOrCreate(self.allocator, .{ .volume = volume }, self, synthWoodBassTemplate);
    }

    pub fn loadWoodBass(
        self: *PhraseBank,
        seq: *utils.sequencer.Sequencer(T),
        target_track: *utils.sequencer.Track(T),
        start_position: music.position.Position,
        volume: T,
    ) !void {
        const events = try self.getOrCreateWoodBassTemplate(volume);
        for (events) |ev| {
            const cloned = try ev.wave.clone(self.allocator);
            try seq.add(target_track, cloned, .{
                .bar = start_position.bar + ev.bar_offset,
                .beat = start_position.beat + ev.beat_offset,
            });
        }
    }

    fn synthRhodesChordTemplate(self: *PhraseBank, key: RhodesChordKey) ![]InstrumentEvent {
        const volume = key.volume;
        const string_count = key.string_count;
        const phrase_notes = phrases._0006.phrase_data.notes;
        const spb_val: f64 = @floatFromInt(music.tempo.spb(self.bpm, self.sample_rate));

        var template_events = try self.allocator.alloc(InstrumentEvent, phrase_notes.len);
        var synth_idx: usize = 0;
        errdefer {
            for (template_events[0..synth_idx]) |*ev| {
                ev.wave.deinit();
            }
            self.allocator.free(template_events);
        }

        for (phrase_notes) |item| {
            const freq = @as(T, @floatCast(music.scale.Scale.gen(item.note)));
            const length: usize = @intFromFloat(spb_val * item.duration_beats);
            const wave = try synthesizers.rhodes.Rhodes.gen(
                T,
                self.allocator,
                freq,
                self.sample_rate,
                self.channels,
                length,
                volume * item.volume,
                .{},
            );
            const string_idx = if (string_count > 0) item.string % string_count else 0;
            template_events[synth_idx] = .{
                .string_idx = string_idx,
                .bar_offset = item.bar,
                .beat_offset = item.beat,
                .wave = wave,
            };
            synth_idx += 1;
        }

        return template_events;
    }

    fn getOrCreateRhodesChordTemplate(self: *PhraseBank, volume: T, string_count: usize) ![]const InstrumentEvent {
        return self.rhodes_chord.getOrCreate(self.allocator, .{ .volume = volume, .string_count = string_count }, self, synthRhodesChordTemplate);
    }

    pub fn loadRhodesChords(
        self: *PhraseBank,
        seq: *utils.sequencer.Sequencer(T),
        instrument: utils.sequencer.Instrument(T),
        start_position: music.position.Position,
        volume: T,
    ) !void {
        const events = try self.getOrCreateRhodesChordTemplate(volume, instrument.stringCount());
        for (events) |ev| {
            const cloned = try ev.wave.clone(self.allocator);
            try seq.addInstrument(instrument, ev.string_idx, cloned, .{
                .bar = start_position.bar + ev.bar_offset,
                .beat = start_position.beat + ev.beat_offset,
            });
        }
    }

    fn synthRhodesCanonTemplate(self: *PhraseBank, key: RhodesCanonKey) ![]InstrumentEvent {
        const voices = key.voices;
        const string_count = key.string_count;
        const phrase_notes = phrases._0005.phrase_data.notes;
        const spb_val: f64 = @floatFromInt(music.tempo.spb(self.bpm, self.sample_rate));
        const total_events = voices.len * phrase_notes.len;

        var template_events = try self.allocator.alloc(InstrumentEvent, total_events);
        var synth_idx: usize = 0;
        errdefer {
            for (template_events[0..synth_idx]) |*ev| {
                ev.wave.deinit();
            }
            self.allocator.free(template_events);
        }

        for (voices) |voice| {
            const net_semitones = voice.totalSemitones();
            for (phrase_notes) |item| {
                const note_val = item.note.add(net_semitones);
                const freq = @as(T, @floatCast(music.scale.Scale.gen(note_val)));
                const length: usize = @intFromFloat(spb_val * item.duration_beats);
                const wave = try synthesizers.rhodes.Rhodes.gen(
                    T,
                    self.allocator,
                    freq,
                    self.sample_rate,
                    self.channels,
                    length,
                    item.volume * voice.volume,
                    .{},
                );
                const string_idx = if (string_count > 0) (item.string + voice.string_index) % string_count else 0;
                template_events[synth_idx] = .{
                    .string_idx = string_idx,
                    .bar_offset = item.bar + voice.bar_offset,
                    .beat_offset = item.beat + voice.beat_offset,
                    .wave = wave,
                };
                synth_idx += 1;
            }
        }

        return template_events;
    }

    fn getOrCreateRhodesCanonTemplate(
        self: *PhraseBank,
        voices: []const utils.sequencer.Stagger.VoiceConfig(T),
        string_count: usize,
    ) ![]const InstrumentEvent {
        return self.rhodes_canon.getOrCreate(self.allocator, .{ .voices = voices, .string_count = string_count }, self, synthRhodesCanonTemplate);
    }

    pub fn scheduleRhodesCanon(
        self: *PhraseBank,
        seq: *utils.sequencer.Sequencer(T),
        instrument: utils.sequencer.Instrument(T),
        start_position: music.position.Position,
        voices: []const utils.sequencer.Stagger.VoiceConfig(T),
    ) !void {
        const events = try self.getOrCreateRhodesCanonTemplate(voices, instrument.stringCount());
        for (events) |ev| {
            const cloned = try ev.wave.clone(self.allocator);
            try seq.addInstrument(instrument, ev.string_idx, cloned, .{
                .bar = start_position.bar + ev.bar_offset,
                .beat = start_position.beat + ev.beat_offset,
            });
        }
    }

    fn synthArpeggioTemplate(self: *PhraseBank, key: ArpeggioKey) ![]TrackEvent {
        const volume = key.volume;
        const accent_interval = key.accent_interval;
        const octave_offset = key.octave_offset;
        const spb_f: f64 = @floatFromInt(music.tempo.spb(self.bpm, self.sample_rate));
        const note_len: usize = @intFromFloat(spb_f * 0.35);

        var template_events = try self.allocator.alloc(TrackEvent, pattern_notes.len);
        var synth_idx: usize = 0;
        errdefer {
            for (template_events[0..synth_idx]) |*ev| {
                ev.wave.deinit();
            }
            self.allocator.free(template_events);
        }

        for (pattern_notes, 0..) |base_note, idx| {
            const note = base_note.add(octave_offset * 12);
            const bar_offset = idx / 16;
            const beat_in_bar = @as(f64, @floatFromInt(idx % 16)) * 0.25;
            const is_accent = (idx % accent_interval == 0);
            const note_vol = if (is_accent) volume * 1.35 else volume * 0.85;

            var wave = try synthesizers.rhodes.Rhodes.gen(
                T,
                self.allocator,
                note.gen(),
                self.sample_rate,
                self.channels,
                note_len,
                note_vol,
                .{ .decay_rate = 7.0 },
            );
            try filters.decay(T, &wave);

            template_events[synth_idx] = .{
                .bar_offset = bar_offset,
                .beat_offset = beat_in_bar,
                .wave = wave,
            };
            synth_idx += 1;
        }

        return template_events;
    }

    fn getOrCreateArpeggioTemplate(
        self: *PhraseBank,
        volume: T,
        accent_interval: usize,
        octave_offset: isize,
    ) ![]const TrackEvent {
        return self.arpeggio.getOrCreate(self.allocator, .{
            .volume = volume,
            .accent_interval = accent_interval,
            .octave_offset = octave_offset,
        }, self, synthArpeggioTemplate);
    }

    pub fn loadMinimalArpeggio(
        self: *PhraseBank,
        seq: *utils.sequencer.Sequencer(T),
        target_track: *utils.sequencer.Track(T),
        start_bar: usize,
        volume: T,
        accent_interval: usize,
        octave_offset: isize,
    ) !void {
        const events = try self.getOrCreateArpeggioTemplate(volume, accent_interval, octave_offset);
        for (events) |ev| {
            const cloned = try ev.wave.clone(self.allocator);
            try seq.add(target_track, cloned, .{
                .bar = start_bar + ev.bar_offset,
                .beat = ev.beat_offset,
            });
        }
    }
};

test "PhraseBank caches and returns cloned phrase waveforms" {
    const allocator = std.testing.allocator;
    var bank = PhraseBank.init(allocator, BPM, SAMPLE_RATE, CHANNELS);
    defer bank.deinit();

    var seq = utils.sequencer.Sequencer(T).init(allocator, BPM, .{}, SAMPLE_RATE, CHANNELS);
    defer seq.deinit();

    const bass_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("Bass");
    var rhodes_chords = try seq.createInstrument("RhodesChords", 5);
    defer rhodes_chords.deinit(allocator);
    var theme_layers = try seq.createInstrument("ThemeLayers", 3);
    defer theme_layers.deinit(allocator);
    const arpeggio_track_idx = seq.tracks.items.len;
    _ = try seq.createTrack("Arpeggio");

    const bass_track = &seq.tracks.items[bass_track_idx];
    const arpeggio_track = &seq.tracks.items[arpeggio_track_idx];

    // 1. Test WoodBass caching
    try std.testing.expectEqual(@as(usize, 0), bank.wood_bass.synth_count);
    try bank.loadWoodBass(&seq, bass_track, .{ .bar = 0, .beat = 0.0 }, 0.85);
    try std.testing.expectEqual(@as(usize, 1), bank.wood_bass.synth_count);

    try bank.loadWoodBass(&seq, bass_track, .{ .bar = 2, .beat = 0.0 }, 0.85);
    // Cache hit: synth count remains 1
    try std.testing.expectEqual(@as(usize, 1), bank.wood_bass.synth_count);

    try bank.loadWoodBass(&seq, bass_track, .{ .bar = 4, .beat = 0.0 }, 0.70);
    // New volume: synth count increments to 2
    try std.testing.expectEqual(@as(usize, 2), bank.wood_bass.synth_count);

    const wb_event_count = phrases._0007.phrase_data.notes.len;
    for (0..wb_event_count) |i| {
        const ev1 = bass_track.events.items[i];
        const ev2 = bass_track.events.items[i + wb_event_count];
        try std.testing.expect(ev1.wave.samples.ptr != ev2.wave.samples.ptr);
        try std.testing.expectEqualSlices(T, ev1.wave.samples, ev2.wave.samples);
    }

    // 2. Test RhodesChords caching
    try std.testing.expectEqual(@as(usize, 0), bank.rhodes_chord.synth_count);
    try bank.loadRhodesChords(&seq, rhodes_chords, .{ .bar = 0, .beat = 0.0 }, 0.70);
    try std.testing.expectEqual(@as(usize, 1), bank.rhodes_chord.synth_count);

    try bank.loadRhodesChords(&seq, rhodes_chords, .{ .bar = 2, .beat = 0.0 }, 0.70);
    // Cache hit: synth count remains 1
    try std.testing.expectEqual(@as(usize, 1), bank.rhodes_chord.synth_count);

    try bank.loadRhodesChords(&seq, rhodes_chords, .{ .bar = 4, .beat = 0.0 }, 0.50);
    // New volume: synth count increments to 2
    try std.testing.expectEqual(@as(usize, 2), bank.rhodes_chord.synth_count);

    const rc_track0 = try seq.getInstrumentTrack(rhodes_chords, 0);
    try std.testing.expect(rc_track0.events.items.len >= 2);
    try std.testing.expect(rc_track0.events.items[0].wave.samples.ptr != rc_track0.events.items[3].wave.samples.ptr);
    try std.testing.expectEqualSlices(T, rc_track0.events.items[0].wave.samples, rc_track0.events.items[3].wave.samples);

    // 3. Test RhodesCanon caching
    const layer1 = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
    };
    const dual = &[_]utils.sequencer.Stagger.VoiceConfig(T){
        .{ .bar_offset = 0, .string_index = 0, .volume = 0.80 },
        .{ .bar_offset = 1, .string_index = 1, .volume = 0.75, .octaves = 0 },
    };

    try std.testing.expectEqual(@as(usize, 0), bank.rhodes_canon.synth_count);
    try bank.scheduleRhodesCanon(&seq, theme_layers, .{ .bar = 0, .beat = 0.0 }, layer1);
    try std.testing.expectEqual(@as(usize, 1), bank.rhodes_canon.synth_count);

    try bank.scheduleRhodesCanon(&seq, theme_layers, .{ .bar = 2, .beat = 0.0 }, layer1);
    // Cache hit
    try std.testing.expectEqual(@as(usize, 1), bank.rhodes_canon.synth_count);

    try bank.scheduleRhodesCanon(&seq, theme_layers, .{ .bar = 4, .beat = 0.0 }, dual);
    // New config
    try std.testing.expectEqual(@as(usize, 2), bank.rhodes_canon.synth_count);

    const tl_track0 = try seq.getInstrumentTrack(theme_layers, 0);
    try std.testing.expect(tl_track0.events.items.len >= 2);
    try std.testing.expect(tl_track0.events.items[0].wave.samples.ptr != tl_track0.events.items[9].wave.samples.ptr);
    try std.testing.expectEqualSlices(T, tl_track0.events.items[0].wave.samples, tl_track0.events.items[9].wave.samples);

    // 4. Test MinimalArpeggio caching
    try std.testing.expectEqual(@as(usize, 0), bank.arpeggio.synth_count);
    try bank.loadMinimalArpeggio(&seq, arpeggio_track, 0, 0.28, 3, 0);
    try std.testing.expectEqual(@as(usize, 1), bank.arpeggio.synth_count);

    try bank.loadMinimalArpeggio(&seq, arpeggio_track, 2, 0.28, 3, 0);
    // Cache hit
    try std.testing.expectEqual(@as(usize, 1), bank.arpeggio.synth_count);

    try bank.loadMinimalArpeggio(&seq, arpeggio_track, 4, 0.24, 3, 0);
    // New config
    try std.testing.expectEqual(@as(usize, 2), bank.arpeggio.synth_count);

    try std.testing.expect(arpeggio_track.events.items.len >= 64);
    try std.testing.expect(arpeggio_track.events.items[0].wave.samples.ptr != arpeggio_track.events.items[32].wave.samples.ptr);
    try std.testing.expectEqualSlices(T, arpeggio_track.events.items[0].wave.samples, arpeggio_track.events.items[32].wave.samples);
}
