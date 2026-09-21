//! Multi-string or multi-channel instrument mapping to sequencer tracks.

const std = @import("std");
const Position = @import("../position/root.zig").Position;

/// Returns an Instrument type parameterized by sample floating-point type T.
pub fn inner(comptime T: type) type {
    _ = T;
    return struct {
        name: []const u8,
        string_indices: []usize,

        const Self = @This();

        /// Initializes an Instrument instance with track indices for each string/voice.
        pub fn init(name: []const u8, string_indices: []usize) Self {
            return .{
                .name = name,
                .string_indices = string_indices,
            };
        }

        /// Frees instrument string index allocations.
        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.string_indices);
        }

        /// Returns the number of strings/voices associated with this instrument.
        pub fn stringCount(self: Self) usize {
            return self.string_indices.len;
        }

        /// Resolves the underlying track index for a given string index.
        pub fn getTrackIndex(self: Self, string_index: usize) !usize {
            if (string_index >= self.string_indices.len) return error.InvalidStringIndex;
            return self.string_indices[string_index];
        }
    };
}

test "Instrument stringCount and getTrackIndex" {
    const allocator = std.testing.allocator;
    const indices = try allocator.alloc(usize, 3);
    indices[0] = 10;
    indices[1] = 20;
    indices[2] = 30;

    var inst = inner(f64).init("Acoustic Guitar", indices);
    defer inst.deinit(allocator);

    try std.testing.expectEqual(@as(usize, 3), inst.stringCount());
    try std.testing.expectEqual(@as(usize, 10), try inst.getTrackIndex(0));
    try std.testing.expectEqual(@as(usize, 20), try inst.getTrackIndex(1));
    try std.testing.expectEqual(@as(usize, 30), try inst.getTrackIndex(2));
}

test "Instrument getTrackIndex out of range returns error.InvalidStringIndex" {
    const allocator = std.testing.allocator;
    const indices = try allocator.alloc(usize, 1);
    indices[0] = 5;

    var inst = inner(f64).init("Single String", indices);
    defer inst.deinit(allocator);

    try std.testing.expectError(error.InvalidStringIndex, inst.getTrackIndex(1));
    try std.testing.expectError(error.InvalidStringIndex, inst.getTrackIndex(99));
}

test {
    std.testing.refAllDecls(@This());
}
