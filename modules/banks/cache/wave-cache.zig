//! Fixed-capacity cache of synthesized waves keyed by volume.

const std = @import("std");
const lightmix = @import("lightmix");

/// Returns a WaveCache type parameterized by sample type T and the wave-creation function `create`.
///
/// `create(allocator, context, volume)` synthesizes a wave on a cache miss, where `context` is the
/// value passed to `get` (for example the tempo and audio format).
pub fn inner(comptime T: type, comptime create: anytype) type {
    return struct {
        const Self = @This();

        pub const capacity = 16;

        const Entry = struct {
            volume: T,
            wave: lightmix.Wave(T),
        };

        entries: [capacity]?Entry = [_]?Entry{null} ** capacity,
        synth_count: usize = 0,

        pub fn deinit(self: *Self) void {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    entry.wave.deinit();
                }
            }
        }

        /// Returns the cached wave for `volume`, synthesizing it on a miss.
        /// When the cache is full, the wave is synthesized and returned without being cached.
        pub fn get(self: *Self, allocator: std.mem.Allocator, context: anytype, volume: T) !lightmix.Wave(T) {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    if (@abs(entry.volume - volume) < 1e-6) {
                        return entry.wave;
                    }
                } else {
                    const wave = try create(allocator, context, volume);
                    self.synth_count += 1;
                    entry_opt.* = .{ .volume = volume, .wave = wave };
                    return wave;
                }
            }
            self.synth_count += 1;
            return create(allocator, context, volume);
        }
    };
}

fn createConstant(allocator: std.mem.Allocator, level: f64, volume: f64) !lightmix.Wave(f64) {
    const samples = try allocator.alloc(f64, 4);
    @memset(samples, level * volume);
    return .{
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 1,
    };
}

test "WaveCache borrows cached waves, counts syntheses and falls back when full" {
    const allocator = std.testing.allocator;
    const Cache = inner(f64, createConstant);

    var cache: Cache = .{};
    defer cache.deinit();

    const first = try cache.get(allocator, 2.0, 0.5);
    try std.testing.expectEqual(@as(usize, 1), cache.synth_count);

    // Cache hit: borrowed samples, no new synthesis.
    const again = try cache.get(allocator, 2.0, 0.5);
    try std.testing.expectEqual(@as(usize, 1), cache.synth_count);
    try std.testing.expect(first.samples.ptr == again.samples.ptr);
    try std.testing.expectEqualSlices(f64, first.samples, again.samples);

    // Fill the remaining slots, then one more volume is synthesized without being cached.
    for (1..Cache.capacity) |i| {
        _ = try cache.get(allocator, 2.0, 0.5 + @as(f64, @floatFromInt(i)));
    }
    try std.testing.expectEqual(@as(usize, Cache.capacity), cache.synth_count);

    var overflow = try cache.get(allocator, 2.0, 100.0);
    defer overflow.deinit();
    try std.testing.expectEqual(@as(usize, Cache.capacity + 1), cache.synth_count);
}

test {
    std.testing.refAllDecls(@This());
}
