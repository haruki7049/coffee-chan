const std = @import("std");
const lightmix = @import("lightmix");
const position_mod = @import("position.zig");
const track_mod = @import("track.zig");

pub const Position = position_mod.Position;
pub const TimeSignature = position_mod.TimeSignature;
pub const Track = track_mod.Track;
pub const Event = track_mod.Event;

pub fn Sequencer(comptime T: type) type {
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

        pub fn addWave(self: *Self, target_track: *Track(T), wave: lightmix.Wave(T), position: Position) !void {
            try target_track.addWave(self.allocator, wave, position);
        }

        pub fn render(self: *Self) !lightmix.Wave(T) {
            var total_events: usize = 0;
            var max_frame_end: usize = 0;

            // Validate all events and compute maximum frame end
            for (self.tracks.items) |tr| {
                for (tr.events.items) |event| {
                    total_events += 1;
                    if (event.wave.sample_rate != self.sample_rate or event.wave.channels != self.channels) {
                        return error.IncompatibleWaveFormat;
                    }
                    const start_frame = try event.position.toSampleOffset(self.bpm, self.time_signature, self.sample_rate);
                    const wave_frames = event.wave.samples.len / self.channels;
                    const end_frame = start_frame + wave_frames;
                    if (end_frame > max_frame_end) {
                        max_frame_end = end_frame;
                    }
                }
            }

            if (total_events == 0) {
                return error.EmptySong;
            }

            const total_samples = max_frame_end * self.channels;
            const samples = try self.allocator.alloc(T, total_samples);
            @memset(samples, 0);

            // Additive mixing for all events
            for (self.tracks.items) |tr| {
                for (tr.events.items) |event| {
                    const start_frame = try event.position.toSampleOffset(self.bpm, self.time_signature, self.sample_rate);
                    const start_sample = start_frame * self.channels;
                    for (event.wave.samples, 0..) |s, i| {
                        samples[start_sample + i] += s;
                    }
                }
            }

            return lightmix.Wave(T){
                .allocator = self.allocator,
                .sample_rate = self.sample_rate,
                .channels = self.channels,
                .samples = samples,
            };
        }
    };
}

test "Sequencer render basic song" {
    const allocator = std.testing.allocator;
    var seq = Sequencer(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    const samples1 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples1, 0.5);
    var wave1 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples1,
    };
    defer wave1.deinit();

    const samples2 = try allocator.alloc(f64, 44100 * 2);
    @memset(samples2, 0.25);
    var wave2 = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples2,
    };
    defer wave2.deinit();

    const track1 = try seq.createTrack("Melody");
    try seq.addWave(track1, wave1, .{ .bar = 0, .beat = 0.0 });

    const track2 = try seq.createTrack("Harmony");
    try seq.addWave(track2, wave2, .{ .bar = 1, .beat = 0.0 });

    var rendered = try seq.render();
    defer rendered.deinit();

    // Bar 0 -> Bar 1: only track1 (0.5)
    // Bar 1 starts at frame 176400 (4 beats * 44100 samples/beat). wave2 is 1 sec (44100 frames).
    // Total end frame = 176400 + 44100 = 220500 frames. Total samples = 220500 * 2 = 441000.
    try std.testing.expectEqual(@as(usize, 441000), rendered.samples.len);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), rendered.samples[0], 0.0001);
}

test "Sequencer render empty song returns error.EmptySong" {
    const allocator = std.testing.allocator;
    var seq = Sequencer(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    try std.testing.expectError(error.EmptySong, seq.render());
}

test "Sequencer render incompatible format error" {
    const allocator = std.testing.allocator;
    var seq = Sequencer(f64).init(allocator, 60, .{}, 44100, 2);
    defer seq.deinit();

    // 48000 Hz instead of 44100 Hz
    const samples = try allocator.alloc(f64, 48000);
    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 48000,
        .channels = 2,
        .samples = samples,
    };
    defer wave.deinit();

    const track = try seq.createTrack("Test");
    try seq.addWave(track, wave, .{ .bar = 0 });

    try std.testing.expectError(error.IncompatibleWaveFormat, seq.render());
}
