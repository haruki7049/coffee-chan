//! Shared acoustic guitar sound generator for the guitar sandbox compositions.

const std = @import("std");
const lightmix = @import("lightmix");
const synthesizers = @import("synthesizers");

const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;

/// Returns a Karplus-Strong guitar sound generator tuned by its treble string feedback.
/// Uses Karplus-Strong physical modeling for cafe fingerstyle acoustic guitar:
/// - Wound lower strings (< 200 Hz) receive pick-filtering LPF passes
/// - Treble melody strings (>= 200 Hz) use `treble_feedback` as their ringing feedback
/// - Ensures at least 2.5s decay buffer so vibrations resonate naturally until superseded
pub fn SoundGen(comptime treble_feedback: comptime_float) type {
    return struct {
        pub fn gen(
            comptime F: type,
            allocator: std.mem.Allocator,
            frequency: F,
            sample_rate: u32,
            channels: u16,
            length: usize,
            volume: F,
            options: anytype,
        ) !lightmix.Wave(F) {
            _ = options;
            const is_bass = frequency < 200.0;
            const lpf_passes: usize = if (is_bass) 2 else 1;
            const feedback: F = if (is_bass) 0.996 else treble_feedback;

            // Provide generous physical decay time (at least 2.5s) so acoustic strings
            // ring out naturally. VoiceScheduler micro-fades only when successive notes share the same string.
            const min_samples: usize = @intFromFloat(@as(f64, @floatFromInt(sample_rate)) * 2.5);
            const actual_length = @max(length, min_samples);

            return try KarplusStrong.gen(
                F,
                allocator,
                frequency,
                sample_rate,
                channels,
                actual_length,
                volume,
                .{
                    .feedback = feedback,
                    .excitation_lpf_passes = lpf_passes,
                    .filter_weight = 0.5,
                },
            );
        }
    };
}
