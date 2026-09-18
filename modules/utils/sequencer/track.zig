const std = @import("std");
const lightmix = @import("lightmix");
const Position = @import("position.zig");
const Event = @import("event.zig").inner;

pub const Mode = enum {
    monophonic,
    polyphonic,
};

pub fn inner(comptime T: type) type {
    return struct {
        name: []const u8,
        mode: Mode = .monophonic,
        events: std.ArrayList(Event(T)) = .empty,

        const Self = @This();

        pub fn init(name: []const u8) Self {
            return .{
                .name = name,
                .mode = .monophonic,
                .events = .empty,
            };
        }

        pub fn initWithMode(name: []const u8, mode: Mode) Self {
            return .{
                .name = name,
                .mode = mode,
                .events = .empty,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            for (self.events.items) |*event| {
                event.wave.deinit();
            }
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
    var track = inner(f64).init("Test Track");
    defer track.deinit(allocator);

    const samples = try allocator.alloc(f64, 44100);
    const wave = lightmix.Wave(f64){
        .allocator = allocator,
        .sample_rate = 44100,
        .channels = 2,
        .samples = samples,
    };

    try track.addWave(allocator, wave, .{ .bar = 1, .beat = 0.0 });
    try std.testing.expectEqual(@as(usize, 1), track.events.items.len);
    try std.testing.expectEqual(@as(usize, 1), track.events.items[0].position.bar);
}

test {
    std.testing.refAllDecls(@This());
}
