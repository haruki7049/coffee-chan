const std = @import("std");

pub const TimeSignature = struct {
    numerator: usize = 4,
    denominator: usize = 4,
};

pub const Position = struct {
    bar: usize = 0,
    beat: f64 = 0.0,

    /// Calculate the sample frame offset given BPM, Time Signature, and sample rate
    pub fn toSampleOffset(self: Position, bpm: usize, time_sig: TimeSignature, sample_rate: u32) !usize {
        if (std.math.isNan(self.beat) or self.beat < 0.0) {
            return error.InvalidPosition;
        }

        const bpm_f: f64 = @floatFromInt(bpm);
        const sample_rate_f: f64 = @floatFromInt(sample_rate);
        const num_f: f64 = @floatFromInt(time_sig.numerator);

        const spb: f64 = (60.0 / bpm_f) * sample_rate_f;
        const total_beats: f64 = (@as(f64, @floatFromInt(self.bar)) * num_f) + self.beat;

        return @intFromFloat(total_beats * spb);
    }
};

test "Position toSampleOffset 4/4 meter" {
    const pos = Position{ .bar = 1, .beat = 2.0 };
    // 60 BPM, 44100 Hz, 4/4 meter
    // 1 beat = 44100 samples
    // total_beats = 1 * 4 + 2 = 6 beats
    // expected = 6 * 44100 = 264600
    const offset = try pos.toSampleOffset(60, .{}, 44100);
    try std.testing.expectEqual(@as(usize, 264600), offset);
}

test "Position toSampleOffset custom time signature 3/4 meter" {
    const pos = Position{ .bar = 2, .beat = 1.0 };
    const time_sig = TimeSignature{ .numerator = 3, .denominator = 4 };
    // 60 BPM, 44100 Hz, 3/4 meter
    // total_beats = 2 * 3 + 1 = 7 beats
    // expected = 7 * 44100 = 308700
    const offset = try pos.toSampleOffset(60, time_sig, 44100);
    try std.testing.expectEqual(@as(usize, 308700), offset);
}

test "Position toSampleOffset invalid position NaN or negative" {
    const pos_nan = Position{ .bar = 0, .beat = std.math.nan(f64) };
    try std.testing.expectError(error.InvalidPosition, pos_nan.toSampleOffset(60, .{}, 44100));

    const pos_neg = Position{ .bar = 0, .beat = -1.0 };
    try std.testing.expectError(error.InvalidPosition, pos_neg.toSampleOffset(60, .{}, 44100));
}
