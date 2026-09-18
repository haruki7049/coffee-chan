const std = @import("std");
const Position = @import("position.zig");

pub fn inner(comptime T: type) type {
    _ = T;
    return struct {
        name: []const u8,
        string_indices: []usize,

        const Self = @This();

        pub fn init(name: []const u8, string_indices: []usize) Self {
            return .{
                .name = name,
                .string_indices = string_indices,
            };
        }

        pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
            allocator.free(self.string_indices);
        }

        pub fn stringCount(self: Self) usize {
            return self.string_indices.len;
        }

        pub fn getTrackIndex(self: Self, string_index: usize) !usize {
            if (string_index >= self.string_indices.len) return error.InvalidStringIndex;
            return self.string_indices[string_index];
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
