const std = @import("std");
const lightmix = @import("lightmix");
const position_mod = @import("position.zig");

pub const Position = position_mod.Position;

pub fn Event(comptime T: type) type {
    return struct {
        wave: lightmix.Wave(T),
        position: Position,
    };
}

pub fn Track(comptime T: type) type {
    return struct {
        name: []const u8,
        events: std.ArrayList(Event(T)) = .empty,

        const Self = @This();

        pub fn init(name: []const u8) Self {
            return .{
                .name = name,
                .events = .empty,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            self.events.deinit(allocator);
        }

        pub fn addWave(self: *Self, allocator: std.mem.Allocator, wave: lightmix.Wave(T), position: Position) !void {
            try self.events.append(allocator, .{
                .wave = wave,
                .position = position,
            });
        }
    };
}

test "Track addWave" {
    const allocator = std.testing.allocator;
    var track = Track(f64).init("Test Track");
    defer track.deinit(allocator);

    const samples = try allocator.alloc(f64, 44100);
    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples,
    };
    defer wave.deinit();

    try track.addWave(allocator, wave, .{ .bar = 1, .beat = 0.0 });
    try std.testing.expectEqual(@as(usize, 1), track.events.items.len);
    try std.testing.expectEqual(@as(usize, 1), track.events.items[0].position.bar);
}
