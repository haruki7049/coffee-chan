const std = @import("std");

/// Samples per beat.
///
/// BPM = 120, and SAMPLE_RATE = 44100, then spb(BPM, SAMPLE_RATE) is 22050.
pub fn spb(bpm: usize, sample_rate: u32) usize {
    const samples_per_beat: usize = @intFromFloat(@as(f32, @floatFromInt(60)) / @as(f32, @floatFromInt(bpm)) * @as(f32, @floatFromInt(sample_rate)));
    return samples_per_beat;
}

/// Convert duration in beats to number of samples.
pub fn beatsToSamples(duration_beats: f64, bpm: usize, sample_rate: u32) usize {
    const base_spb: f64 = @floatFromInt(spb(bpm, sample_rate));
    return @intFromFloat(base_spb * duration_beats);
}

test "spb" {
    try std.testing.expectEqual(@as(usize, 22050), spb(120, 44100));
}

test "beatsToSamples" {
    try std.testing.expectEqual(@as(usize, 44100), beatsToSamples(2.0, 120, 44100));
}

test {
    std.testing.refAllDecls(@This());
}
