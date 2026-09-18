const std = @import("std");
const utils = @import("utils");
const NoteEvent = utils.sequencer.NoteEvent;

pub fn PhraseData(comptime T: type, comptime NoteType: type) type {
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
        ) ![]NoteEvent(T) {
            var events = try allocator.alloc(NoteEvent(T), self.notes.len);

            for (self.notes, 0..) |item, i| {
                events[i] = .{
                    .position = .{ .bar = item.bar, .beat = item.beat },
                    .freq = @floatCast(ScaleGen.gen(item.note)),
                    .length = utils.tempo.beatsToSamples(item.duration_beats, bpm, sample_rate),
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
