const std = @import("std");
const lightmix = @import("lightmix");
const Position = @import("position.zig");
const TimeSignature = @import("time_signature.zig");
const Track = @import("track.zig").inner;
const Instrument = @import("instrument.zig").inner;
const VoiceScheduler = @import("voice_scheduler.zig").inner;
const Renderer = @import("renderer.zig").inner;
const Note = @import("../note/root.zig").Note;

pub fn inner(comptime T: type) type {
    return struct {
        allocator: std.mem.Allocator,
        bpm: usize,
        time_signature: TimeSignature,
        sample_rate: u32,
        channels: u16,
        tracks: std.ArrayList(Track(T)) = .empty,

        const Self = @This();

        pub fn init(
            allocator: std.mem.Allocator,
            bpm: usize,
            time_signature: TimeSignature,
            sample_rate: u32,
            channels: u16,
        ) Self {
            return .{
                .allocator = allocator,
                .bpm = bpm,
                .time_signature = time_signature,
                .sample_rate = sample_rate,
                .channels = channels,
                .tracks = .empty,
            };
        }

        pub fn deinit(self: *Self) void {
            for (self.tracks.items) |*tr| {
                tr.deinit(self.allocator);
            }
            self.tracks.deinit(self.allocator);
        }

        pub fn createTrack(self: *Self, name: []const u8) !*Track(T) {
            try self.tracks.append(self.allocator, Track(T).init(name));
            return &self.tracks.items[self.tracks.items.len - 1];
        }

        pub fn createInstrument(self: *Self, name: []const u8, string_count: usize) !Instrument(T) {
            const start_idx = self.tracks.items.len;
            for (0..string_count) |_| {
                _ = try self.createTrack(name);
            }
            var indices = try self.allocator.alloc(usize, string_count);
            for (0..string_count) |i| {
                indices[i] = start_idx + i;
            }
            return Instrument(T).init(name, indices);
        }

        pub fn getInstrumentTrack(self: *Self, instrument: Instrument(T), string_index: usize) !*Track(T) {
            const idx = try instrument.getTrackIndex(string_index);
            return &self.tracks.items[idx];
        }

        pub fn addInstrumentWave(
            self: *Self,
            instrument: Instrument(T),
            string_index: usize,
            wave: lightmix.Wave(T),
            position: Position,
        ) !void {
            const tr = try self.getInstrumentTrack(instrument, string_index);
            try self.addWave(tr, wave, position);
        }

        pub fn addWave(self: *Self, target_track: *Track(T), wave: lightmix.Wave(T), position: Position) !void {
            try target_track.addWave(self.allocator, wave, position);
        }

        pub fn addEvents(
            self: *Self,
            target_track: *Track(T),
            comptime SoundGen: type,
            events: []const Note(T),
            master_volume: T,
        ) !void {
            for (events) |event| {
                const note_wave = try SoundGen.gen(
                    T,
                    self.allocator,
                    event.freq,
                    self.sample_rate,
                    self.channels,
                    event.length,
                    master_volume * event.volume,
                    .{},
                );

                try self.addWave(target_track, note_wave, event.position);
            }
        }

        pub fn render(self: *Self) !lightmix.Wave(T) {
            var total_events: usize = 0;

            // Validate all events format
            for (self.tracks.items) |tr| {
                for (tr.events.items) |event| {
                    total_events += 1;
                    if (event.wave.sample_rate != self.sample_rate or event.wave.channels != self.channels) {
                        return error.IncompatibleWaveFormat;
                    }
                }
            }

            if (total_events == 0) {
                return error.EmptySong;
            }

            // Default 5ms micro-fade frames (e.g. 220 samples at 44.1kHz)
            const fade_frames: usize = @max(1, @as(usize, @intFromFloat(@as(f64, @floatFromInt(self.sample_rate)) * 0.005)));

            // Schedule all tracks once using VoiceScheduler
            const Scheduler = VoiceScheduler(T);
            var track_schedules = try self.allocator.alloc([]Scheduler.ScheduledEvent, self.tracks.items.len);
            @memset(track_schedules, &[_]Scheduler.ScheduledEvent{});
            defer {
                for (track_schedules) |sched| {
                    if (sched.len > 0) {
                        self.allocator.free(sched);
                    }
                }
                self.allocator.free(track_schedules);
            }

            var max_frame_end: usize = 0;
            for (self.tracks.items, 0..) |tr, tr_idx| {
                track_schedules[tr_idx] = try Scheduler.scheduleTrack(
                    self.allocator,
                    tr,
                    self.bpm,
                    self.time_signature,
                    self.sample_rate,
                    self.channels,
                    fade_frames,
                );
                for (track_schedules[tr_idx]) |se| {
                    if (se.active_frames > 0) {
                        max_frame_end = @max(max_frame_end, se.start_frame + se.active_frames);
                    }
                }
            }

            return Renderer(T).render(
                self.allocator,
                self.sample_rate,
                self.channels,
                self.tracks.items,
                track_schedules,
                max_frame_end,
            );
        }
    };
}

test "Sequencer render basic song" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples1, 0.5);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples2, 0.25);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples2,
    };

    const track1 = try seq.createTrack("Melody");
    try seq.addWave(track1, wave1, .{ .bar = 0, .beat = 0.0 });

    const track2 = try seq.createTrack("Harmony");
    try seq.addWave(track2, wave2, .{ .bar = 1, .beat = 0.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    try std.testing.expectEqual(@as(usize, 441000), rendered.samples.len);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), rendered.samples[0], 0.0001);
}

test "Sequencer render empty song returns error.EmptySong" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    try std.testing.expectError(error.EmptySong, seq.render());
}

test "Sequencer render incompatible format error" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    const samples = try allocator.alloc(f64, 48000);
    const wave = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 48000,
        .channels = 2,
        .samples = samples,
    };

    const track = try seq.createTrack("Test");
    try seq.addWave(track, wave, .{ .bar = 0 });

    try std.testing.expectError(error.IncompatibleWaveFormat, seq.render());
}

test "Sequencer render track truncates overlapping waves with micro-fade (Single String Model)" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    // Wave 1: 4 seconds long, amplitude 1.0
    const samples1 = try allocator.alloc(f64, 44100 * 4);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    // Wave 2: 2 seconds long, amplitude 1.0
    const samples2 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("MonoTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 2.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[0], 0.001);

    // Wave 2 starts at 2 beats (2.0s = 88200 samples at 60 bpm)
    // After micro-fade (220 samples), Wave 1 is completely cut off so amplitude must be 1.0, not 2.0
    const sample_after_fade = 88200 + 250;
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[sample_after_fade], 0.001);
}

test "Sequencer render three consecutive overlapping waves cascade voice priority" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 4);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100 * 3);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const samples3 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples3, 1.0);
    const wave3 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples3,
    };

    const track = try seq.createTrack("CascadeTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 1.0 });
    try seq.addWave(track, wave3, .{ .bar = 0, .beat = 2.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // Wave 1 plays alone at t=0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[0], 0.001);

    // Wave 2 starts at t=1s (44100). 250 samples after 44100, Wave 1 is completely faded out
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[44100 + 250], 0.001);

    // Wave 3 starts at t=2s (88200). 250 samples after 88200, Wave 2 is completely faded out
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[88200 + 250], 0.001);
}

test "Sequencer render same timestamp collision supersedes earlier wave" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100);
    @memset(samples1, 0.3);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.7);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("CollisionTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 0.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // Wave 1 should be silenced (active_frames = 0), Wave 2 should sound at 0.7
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), rendered.samples[0], 0.001);
}

test "Sequencer render notes separated by silence play full duration without fade" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    // 1 beat = 1 second = 44100 samples
    const samples1 = try allocator.alloc(f64, 44100);
    @memset(samples1, 0.8);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.8);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("GapTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 }); // 0s - 1s
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 2.0 }); // 2s - 3s (1s gap)

    var rendered = try seq.render();
    defer rendered.deinit();

    // Near the end of Wave 1, should still be full amplitude (no early fade-out)
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), rendered.samples[44090], 0.001);

    // During the silence gap (1.5s = 66150 samples), amplitude is 0.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), rendered.samples[66150], 0.001);

    // Wave 2 starts at 2s (88200 samples)
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), rendered.samples[88200], 0.001);
}

test "Sequencer render note shorter than fade window does not underflow or crash" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    // 50 samples is much shorter than default 5ms (220 samples) fade
    const samples1 = try allocator.alloc(f64, 50);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.5);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("ShortNoteTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 20.0 / 44100.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    try std.testing.expect(rendered.samples.len > 0);
}

test "Sequencer render multi-track polyphony mixes additively without cross-track truncation" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100);
    @memset(samples1, 0.3);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.5);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track1 = try seq.createTrack("Track1");
    try seq.addWave(track1, wave1, .{ .bar = 0, .beat = 0.0 });

    const track2 = try seq.createTrack("Track2");
    try seq.addWave(track2, wave2, .{ .bar = 0, .beat = 0.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // 0.3 + 0.5 = 0.8
    try std.testing.expectApproxEqAbs(@as(f64, 0.8), rendered.samples[0], 0.001);
}

test "Sequencer render rapid succession notes clamps preceding micro-fade before third note" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const samples3 = try allocator.alloc(f64, 44100);
    @memset(samples3, 1.0);
    const wave3 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples3,
    };

    const track = try seq.createTrack("RapidTrack");
    // Wave 1 at t=0
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    // Wave 2 at frame 50
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 50.0 / 44100.0 });
    // Wave 3 at frame 80
    try seq.addWave(track, wave3, .{ .bar = 0, .beat = 80.0 / 44100.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // After Wave 2's fade finishes (80 + 220 = 300), only Wave 3 is sounding at amplitude 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[350], 0.001);
}

test "Sequencer render buffer length matches truncated notes instead of untruncated duration" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    // Wave 1: 10 seconds long
    const samples1 = try allocator.alloc(f64, 44100 * 10);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    // Wave 2: 1 second long, starting at 1.0s (beat 1.0)
    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("TruncatedBufferTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 1.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // Wave 2 ends at 2.0s = 88200 samples.
    // Wave 1 truncated duration was 44100 + 220 = 44320 samples.
    // Total rendered samples should be 88200, NOT 441000 (10 seconds)!
    try std.testing.expectEqual(@as(usize, 88200), rendered.samples.len);
}

test "Sequencer render applies attack micro-fade-in on interrupting overlapping note" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("AttackTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 1.0 }); // frame 44100

    var rendered = try seq.render();
    defer rendered.deinit();

    // Wave 1 begins at full amplitude at t=0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[0], 0.001);

    // During crossfade transition (frame 44100), Wave 1 fades out as Wave 2 fades in
    // Total sum at transition is smooth (approximately 1.414 for equal-power in-phase, not jumping to 2.0 or 0.0)
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[44100], 0.01);
    try std.testing.expectApproxEqAbs(@as(f64, 1.4142), rendered.samples[44100 + 110], 0.02);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), rendered.samples[44100 + 220], 0.01);
}

test "Sequencer render micro-fade uses equal-power curve" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples1, 1.0);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("EqualPowerTrack");
    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 1.0 }); // frame 44100

    var rendered = try seq.render();
    defer rendered.deinit();

    // At midpoint of 220-sample fade (~110 samples after 44100), equal-power cosine is cos(pi/4) ≈ 0.7071
    // (Linear fade would have been 0.5)
    try std.testing.expectApproxEqAbs(@as(f64, 0.7071), rendered.samples[44100 + 110], 0.02);
}

test "Sequencer Instrument groups tracks as strings and plays polyphonic chords" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    var guitar = try seq.createInstrument("AcousticGuitar", 6);
    defer guitar.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 6), guitar.stringCount());

    const samples1 = try allocator.alloc(f64, 44100);
    @memset(samples1, 0.4);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 0.5);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    // Play string 0 and string 1 simultaneously (chord)
    try seq.addInstrumentWave(guitar, 0, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addInstrumentWave(guitar, 1, wave2, .{ .bar = 0, .beat = 0.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // 0.4 + 0.5 = 0.9 (both strings sound together)
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), rendered.samples[0], 0.001);
}

test "Sequencer render honors enable_attack_fade = false for percussive tracks" {
    const allocator = std.testing.allocator;
    var seq = inner(f64).init(allocator, 60, .{}, 44100, 1);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples1, 0.5);
    const wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples1,
    };

    const samples2 = try allocator.alloc(f64, 44100);
    @memset(samples2, 1.0);
    const wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 1,
        .samples = samples2,
    };

    const track = try seq.createTrack("PercussionTrack");
    track.enable_attack_fade = false;

    try seq.addWave(track, wave1, .{ .bar = 0, .beat = 0.0 });
    try seq.addWave(track, wave2, .{ .bar = 0, .beat = 1.0 }); // frame 44100

    var rendered = try seq.render();
    defer rendered.deinit();

    // At onset frame 44100: Wave 2 starts immediately at amplitude 1.0 (no sine fade-in ramp from 0.0),
    // while Wave 1 starts fading out from 0.5 with equal-power cosine.
    // 0.5 * cos(0) + 1.0 = 1.5 (Wave 2 transient preserved immediately).
    try std.testing.expectApproxEqAbs(@as(f64, 1.5), rendered.samples[44100], 0.01);
}

test {
    std.testing.refAllDecls(@This());
}
