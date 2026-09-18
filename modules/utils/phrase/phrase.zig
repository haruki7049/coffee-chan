const std = @import("std");
const utils = @import("../root.zig");
const Note = utils.note.Note;

pub fn Phrase(comptime T: type, comptime NoteType: type) type {
    return struct {
        const Self = @This();

        pub const RawNote = struct {
            bar: usize = 0,
            beat: f64 = 0.0,
            note: NoteType,
            duration_beats: f64 = 1.0,
            volume: T = 1.0,
        };

        name: []const u8,
        notes: []const RawNote,

        pub fn toEvents(
            self: Self,
            comptime ScaleGen: type,
            allocator: std.mem.Allocator,
            bpm: usize,
            sample_rate: u32,
        ) ![]Note(T) {
            var events = try allocator.alloc(Note(T), self.notes.len);

            const spb_val: f64 = @floatFromInt(utils.tempo.spb(bpm, sample_rate));

            for (self.notes, 0..) |item, i| {
                events[i] = .{
                    .position = .{ .bar = item.bar, .beat = item.beat },
                    .freq = @floatCast(ScaleGen.gen(item.note)),
                    .length = @intFromFloat(spb_val * item.duration_beats),
                    .volume = item.volume,
                };
            }

            return events;
        }
    };
}

test {
    std.testing.refAllDecls(@This());
}
