//! Fixed-capacity cache of synthesized event templates keyed by a caller-defined key type.

const std = @import("std");
const lightmix = @import("lightmix");

/// Returns a TemplateCache type keyed by `K` and holding event slices of `E`.
///
/// `K` must declare `pub fn eql(a: K, b: K) bool`. If `K` also declares `pub fn dupe(self, allocator)` and
/// `pub fn deinit(self, allocator)`, the cache stores an owned copy of the key and frees it on `deinit`.
/// `E` must have a `wave` field with a `deinit` method (for example `lightmix.Wave(T)`).
pub fn inner(comptime K: type, comptime E: type) type {
    return struct {
        const Self = @This();
        pub const capacity = 16;

        const Entry = struct {
            key: K,
            events: []E,
        };

        entries: [capacity]?Entry = [_]?Entry{null} ** capacity,
        synth_count: usize = 0,

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    for (entry.events) |*ev| {
                        ev.wave.deinit();
                    }
                    allocator.free(entry.events);
                    if (@hasDecl(K, "deinit")) entry.key.deinit(allocator);
                    entry_opt.* = null;
                }
            }
        }

        /// Returns the cached events for `key`, synthesizing them with `synth(ctx, key)` on a miss.
        /// Returns `error.CacheFull` when `key` is not cached and every slot is already in use.
        pub fn getOrCreate(
            self: *Self,
            allocator: std.mem.Allocator,
            key: K,
            ctx: anytype,
            comptime synth: anytype,
        ) ![]const E {
            for (&self.entries) |*entry_opt| {
                if (entry_opt.*) |entry| {
                    if (K.eql(entry.key, key)) {
                        return entry.events;
                    }
                } else {
                    const owned_key = if (@hasDecl(K, "dupe")) try key.dupe(allocator) else key;
                    errdefer if (@hasDecl(K, "deinit")) owned_key.deinit(allocator);
                    const events = try synth(ctx, key);
                    self.synth_count += 1;
                    entry_opt.* = .{ .key = owned_key, .events = events };
                    return events;
                }
            }
            return error.CacheFull;
        }
    };
}

test "TemplateCache returns error.CacheFull when every slot is in use" {
    const allocator = std.testing.allocator;

    const Event = struct { wave: lightmix.Wave(f64) };
    const Key = struct {
        id: usize,

        fn eql(a: @This(), b: @This()) bool {
            return a.id == b.id;
        }
    };
    const Cache = inner(Key, Event);
    const Synth = struct {
        allocator: std.mem.Allocator,

        fn synth(self: @This(), key: Key) ![]Event {
            _ = key;
            const events = try self.allocator.alloc(Event, 1);
            errdefer self.allocator.free(events);
            const samples = try self.allocator.alloc(f64, 1);
            samples[0] = 0.0;
            events[0] = .{ .wave = .{
                .allocator = self.allocator,
                .samples = samples,
                .sample_rate = 44100,
                .channels = 1,
            } };
            return events;
        }
    };

    var cache: Cache = .{};
    defer cache.deinit(allocator);
    const synth = Synth{ .allocator = allocator };

    for (0..Cache.capacity) |i| {
        _ = try cache.getOrCreate(allocator, .{ .id = i }, synth, Synth.synth);
    }
    try std.testing.expectEqual(@as(usize, Cache.capacity), cache.synth_count);

    // A new key cannot be cached and reports the dedicated error instead of error.OutOfMemory.
    try std.testing.expectError(
        error.CacheFull,
        cache.getOrCreate(allocator, .{ .id = Cache.capacity }, synth, Synth.synth),
    );
    try std.testing.expectEqual(@as(usize, Cache.capacity), cache.synth_count);

    // Existing keys are still served from the cache when it is full.
    _ = try cache.getOrCreate(allocator, .{ .id = 0 }, synth, Synth.synth);
    try std.testing.expectEqual(@as(usize, Cache.capacity), cache.synth_count);
}

test {
    std.testing.refAllDecls(@This());
}
