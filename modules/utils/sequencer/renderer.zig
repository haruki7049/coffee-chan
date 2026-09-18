const std = @import("std");
const lightmix = @import("lightmix");
const Track = @import("track.zig").inner;
const VoiceScheduler = @import("voice_scheduler.zig").inner;

pub fn inner(comptime T: type) type {
    return struct {
        const Self = @This();
        pub const Scheduler = VoiceScheduler(T);
        pub const ScheduledEvent = Scheduler.ScheduledEvent;

        /// Computes equal-power micro-fade gain for a given frame within a scheduled event.
        pub fn computeGain(se: ScheduledEvent, frame_idx: usize) T {
            var gain: T = 1.0;
            if (se.has_attack_fade and frame_idx < se.attack_fade_len and se.attack_fade_len > 0) {
                const attack_progress = @as(f64, @floatFromInt(frame_idx + 1)) / @as(f64, @floatFromInt(se.attack_fade_len));
                gain *= @as(T, @floatCast(@sin(attack_progress * (std.math.pi / 2.0))));
            }
            if (se.has_fade and frame_idx >= se.fade_start_offset and se.actual_fade_len > 0) {
                const fade_idx = frame_idx - se.fade_start_offset;
                const progress = @as(f64, @floatFromInt(fade_idx + 1)) / @as(f64, @floatFromInt(se.actual_fade_len));
                gain *= @as(T, @floatCast(@cos(progress * (std.math.pi / 2.0))));
            }
            return gain;
        }

        /// Mixes an active scheduled event into the destination sample buffer with equal-power micro-fade gains.
        pub fn mixEvent(
            samples: []T,
            channels: u16,
            event_wave: lightmix.Wave(T),
            se: ScheduledEvent,
        ) void {
            if (se.active_frames == 0) return;

            const start_sample = se.start_frame * channels;
            for (0..se.active_frames) |frame_idx| {
                const gain = computeGain(se, frame_idx);
                for (0..channels) |ch| {
                    const sample_val = event_wave.samples[frame_idx * channels + ch] * gain;
                    samples[start_sample + frame_idx * channels + ch] += sample_val;
                }
            }
        }

        /// Allocates sample buffer and renders scheduled track events into a lightmix.Wave(T).
        pub fn render(
            allocator: std.mem.Allocator,
            sample_rate: u32,
            channels: u16,
            tracks: []const Track(T),
            track_schedules: []const []const ScheduledEvent,
            max_frame_end: usize,
        ) !lightmix.Wave(T) {
            if (max_frame_end == 0) {
                return error.EmptySong;
            }

            const total_samples = max_frame_end * channels;
            const samples = try allocator.alloc(T, total_samples);
            @memset(samples, 0);

            for (tracks, 0..) |tr, tr_idx| {
                for (track_schedules[tr_idx]) |se| {
                    if (se.active_frames == 0) continue;
                    const event = tr.events.items[se.event_index];
                    mixEvent(samples, channels, event.wave, se);
                }
            }

            return lightmix.Wave(T){
                .allocator = allocator,
                .sample_rate = sample_rate,
                .channels = channels,
                .samples = samples,
            };
        }
    };
}

test "Renderer computeGain with no fades returns 1.0" {
    const TheRenderer = inner(f64);
    const se: TheRenderer.ScheduledEvent = .{
        .event_index = 0,
        .start_frame = 0,
        .active_frames = 100,
        .fade_start_offset = 100,
        .actual_fade_len = 0,
        .has_fade = false,
        .has_attack_fade = false,
        .attack_fade_len = 0,
    };

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), TheRenderer.computeGain(se, 0), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), TheRenderer.computeGain(se, 50), 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), TheRenderer.computeGain(se, 99), 0.0001);
}

test "Renderer computeGain with attack fade follows sine curve" {
    const TheRenderer = inner(f64);
    const se: TheRenderer.ScheduledEvent = .{
        .event_index = 0,
        .start_frame = 0,
        .active_frames = 100,
        .fade_start_offset = 100,
        .actual_fade_len = 0,
        .has_fade = false,
        .has_attack_fade = true,
        .attack_fade_len = 100,
    };

    // frame 0: (1/100) * pi/2 => sin
    const expected_start = @sin(1.0 / 100.0 * (std.math.pi / 2.0));
    try std.testing.expectApproxEqAbs(expected_start, TheRenderer.computeGain(se, 0), 0.0001);

    // frame 99: (100/100) * pi/2 = pi/2 => sin = 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), TheRenderer.computeGain(se, 99), 0.0001);
}

test "Renderer computeGain with decay fade follows cosine curve" {
    const TheRenderer = inner(f64);
    const se: TheRenderer.ScheduledEvent = .{
        .event_index = 0,
        .start_frame = 0,
        .active_frames = 100,
        .fade_start_offset = 80,
        .actual_fade_len = 20,
        .has_fade = true,
        .has_attack_fade = false,
        .attack_fade_len = 0,
    };

    // Before fade start: gain = 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), TheRenderer.computeGain(se, 79), 0.0001);

    // At fade start (frame 80): (1/20) * pi/2 => cos
    const expected_fade_start = @cos(1.0 / 20.0 * (std.math.pi / 2.0));
    try std.testing.expectApproxEqAbs(expected_fade_start, TheRenderer.computeGain(se, 80), 0.0001);

    // At final fade frame (frame 99): (20/20) * pi/2 => cos(pi/2) = 0.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.0), TheRenderer.computeGain(se, 99), 0.0001);
}

test "Renderer mixEvent accumulates multi-channel samples with gain" {
    const allocator = std.testing.allocator;
    const TheRenderer = inner(f64);

    const wave_samples = try allocator.alloc(f64, 4);
    wave_samples[0] = 0.5; // frame 0, ch 0
    wave_samples[1] = 0.8; // frame 0, ch 1
    wave_samples[2] = 0.6; // frame 1, ch 0
    wave_samples[3] = 0.9; // frame 1, ch 1
    const wave = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = wave_samples,
    };
    defer wave.deinit();

    const dest = try allocator.alloc(f64, 8);
    @memset(dest, 0.1);
    defer allocator.free(dest);

    const se: TheRenderer.ScheduledEvent = .{
        .event_index = 0,
        .start_frame = 1,
        .active_frames = 2,
        .fade_start_offset = 2,
        .actual_fade_len = 0,
        .has_fade = false,
        .has_attack_fade = false,
        .attack_fade_len = 0,
    };

    TheRenderer.mixEvent(dest, 2, wave, se);

    // Frame 0 of dest (start_frame=1 so frame 0 is untouched)
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), dest[0], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.1), dest[1], 0.0001);

    // Frame 1 of dest: 0.1 + 0.5 = 0.6, 0.1 + 0.8 = 0.9
    try std.testing.expectApproxEqAbs(@as(f64, 0.6), dest[2], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 0.9), dest[3], 0.0001);

    // Frame 2 of dest: 0.1 + 0.6 = 0.7, 0.1 + 0.9 = 1.0
    try std.testing.expectApproxEqAbs(@as(f64, 0.7), dest[4], 0.0001);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), dest[5], 0.0001);
}

test "Renderer render empty max_frame_end returns error.EmptySong" {
    const allocator = std.testing.allocator;
    const TheRenderer = inner(f64);
    const result = TheRenderer.render(allocator, 44100, 2, &[_]Track(f64){}, &[_][]const TheRenderer.ScheduledEvent{}, 0);
    try std.testing.expectError(error.EmptySong, result);
}

test {
    std.testing.refAllDecls(@This());
}
