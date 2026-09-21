//! Cached kick and hi-hat waveform banks for the composition.

const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const synthesizers = @import("synthesizers");
const utils = @import("utils");
const config = @import("config.zig");

const T = config.T;
const BPM = config.BPM;
const SAMPLE_RATE = config.SAMPLE_RATE;
const CHANNELS = config.CHANNELS;

/// Tempo and audio format used to synthesize drum waves.
const Format = struct {
    bpm: usize,
    sample_rate: u32,
    channels: u16,
};

fn createKickWave(allocator: std.mem.Allocator, format: Format, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(format.bpm, format.sample_rate));
    const kick_len: usize = @intFromFloat(spb_val * 0.4);
    var wave = try synthesizers.sine.Sine.gen(T, allocator, 60.0, format.sample_rate, format.channels, kick_len, volume, .{});
    try filters.decay(T, &wave);
    return wave;
}

fn createHiHatWave(allocator: std.mem.Allocator, format: Format, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(format.bpm, format.sample_rate));
    const hat_len: usize = @intFromFloat(spb_val * 0.15);
    var wave = try synthesizers.whitenoise.WhiteNoise.gen(T, allocator, format.sample_rate, format.channels, hat_len, volume);
    try filters.decay(T, &wave);
    return wave;
}

pub const DrumBank = struct {
    allocator: std.mem.Allocator,
    format: Format,
    kicks: utils.cache.WaveCache(T, createKickWave) = .{},
    hihats: utils.cache.WaveCache(T, createHiHatWave) = .{},

    pub fn init(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16) DrumBank {
        return .{
            .allocator = allocator,
            .format = .{ .bpm = bpm, .sample_rate = sample_rate, .channels = channels },
        };
    }

    pub fn deinit(self: *DrumBank) void {
        self.kicks.deinit();
        self.hihats.deinit();
    }

    pub fn getKick(self: *DrumBank, volume: T) !lightmix.Wave(T) {
        return self.kicks.get(self.allocator, self.format, volume);
    }

    pub fn getHiHat(self: *DrumBank, volume: T) !lightmix.Wave(T) {
        return self.hihats.get(self.allocator, self.format, volume);
    }
};

test "DrumBank caches and returns cloned waveforms" {
    const allocator = std.testing.allocator;
    var bank = DrumBank.init(allocator, BPM, SAMPLE_RATE, CHANNELS);
    defer bank.deinit();

    try std.testing.expectEqual(@as(usize, 0), bank.kicks.synth_count);
    var kick1 = try bank.getKick(0.5);
    defer kick1.deinit();
    try std.testing.expectEqual(@as(usize, 1), bank.kicks.synth_count);

    var kick2 = try bank.getKick(0.5);
    defer kick2.deinit();
    // Cache hit: synth count remains 1
    try std.testing.expectEqual(@as(usize, 1), bank.kicks.synth_count);

    var kick3 = try bank.getKick(0.6);
    defer kick3.deinit();
    // New volume: synth count increments to 2
    try std.testing.expectEqual(@as(usize, 2), bank.kicks.synth_count);

    try std.testing.expectEqual(kick1.samples.len, kick2.samples.len);
    try std.testing.expectEqualSlices(T, kick1.samples, kick2.samples);
    try std.testing.expect(kick1.samples.ptr != kick2.samples.ptr);

    try std.testing.expectEqual(@as(usize, 0), bank.hihats.synth_count);
    var hat1 = try bank.getHiHat(0.2);
    defer hat1.deinit();
    try std.testing.expectEqual(@as(usize, 1), bank.hihats.synth_count);

    var hat2 = try bank.getHiHat(0.2);
    defer hat2.deinit();
    // Cache hit: synth count remains 1
    try std.testing.expectEqual(@as(usize, 1), bank.hihats.synth_count);

    var hat3 = try bank.getHiHat(0.3);
    defer hat3.deinit();
    // New volume: synth count increments to 2
    try std.testing.expectEqual(@as(usize, 2), bank.hihats.synth_count);

    try std.testing.expectEqual(hat1.samples.len, hat2.samples.len);
    try std.testing.expectEqualSlices(T, hat1.samples, hat2.samples);
    try std.testing.expect(hat1.samples.ptr != hat2.samples.ptr);
}
