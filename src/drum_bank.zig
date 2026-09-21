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

fn createKickWave(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(bpm, sample_rate));
    const kick_len: usize = @intFromFloat(spb_val * 0.4);
    var wave = try synthesizers.sine.Sine.gen(T, allocator, 60.0, sample_rate, channels, kick_len, volume, .{});
    try filters.decay(T, &wave);
    return wave;
}

fn createHiHatWave(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
    const spb_val: f64 = @floatFromInt(utils.tempo.spb(bpm, sample_rate));
    const hat_len: usize = @intFromFloat(spb_val * 0.15);
    var wave = try synthesizers.whitenoise.WhiteNoise.gen(T, allocator, sample_rate, channels, hat_len, volume);
    try filters.decay(T, &wave);
    return wave;
}

/// Fixed-capacity cache of synthesized waves keyed by volume.
/// `create(allocator, bpm, sample_rate, channels, volume)` synthesizes a wave on a cache miss.
fn WaveCache(comptime create: anytype) type {
    return struct {
        const Self = @This();
        const capacity = 16;

        const Entry = struct {
            volume: T,
            wave: lightmix.Wave(T),
        };

        entries: [capacity]?Entry = [_]?Entry{null} ** capacity,
        synth_count: usize = 0,

        fn deinit(self: *Self) void {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    entry.wave.deinit();
                }
            }
        }

        /// Returns a clone of the cached wave for `volume`, synthesizing it on a miss.
        /// When the cache is full, the wave is synthesized and returned without being cached.
        fn get(self: *Self, allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16, volume: T) !lightmix.Wave(T) {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    if (@abs(entry.volume - volume) < 1e-6) {
                        return entry.wave.clone(allocator);
                    }
                } else {
                    const wave = try create(allocator, bpm, sample_rate, channels, volume);
                    self.synth_count += 1;
                    entry_opt.* = .{ .volume = volume, .wave = wave };
                    return wave.clone(allocator);
                }
            }
            self.synth_count += 1;
            return create(allocator, bpm, sample_rate, channels, volume);
        }
    };
}

pub const DrumBank = struct {
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    kicks: WaveCache(createKickWave) = .{},
    hihats: WaveCache(createHiHatWave) = .{},

    pub fn init(allocator: std.mem.Allocator, bpm: usize, sample_rate: u32, channels: u16) DrumBank {
        return .{
            .allocator = allocator,
            .bpm = bpm,
            .sample_rate = sample_rate,
            .channels = channels,
        };
    }

    pub fn deinit(self: *DrumBank) void {
        self.kicks.deinit();
        self.hihats.deinit();
    }

    pub fn getKick(self: *DrumBank, volume: T) !lightmix.Wave(T) {
        return self.kicks.get(self.allocator, self.bpm, self.sample_rate, self.channels, volume);
    }

    pub fn getHiHat(self: *DrumBank, volume: T) !lightmix.Wave(T) {
        return self.hihats.get(self.allocator, self.bpm, self.sample_rate, self.channels, volume);
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
