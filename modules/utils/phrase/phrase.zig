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
            string: usize = 0,
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
                    .string = item.string,
                };
            }

            return events;
        }
    };
}

test "Phrase toEvents preserves string attribute" {
    const allocator = std.testing.allocator;
    const DummyScale = struct {
        fn gen(_: u8) f64 {
            return 440.0;
        }
    };
    const DummyPhrase = Phrase(f64, u8){
        .name = "Test Chord Phrase",
        .notes = &[_]Phrase(f64, u8).RawNote{
            .{ .bar = 0, .beat = 0.0, .note = 1, .string = 0 },
            .{ .bar = 0, .beat = 0.0, .note = 2, .string = 1 },
            .{ .bar = 0, .beat = 0.0, .note = 3, .string = 2 },
        },
    };

    const events = try DummyPhrase.toEvents(DummyScale, allocator, 120, 44100);
    defer allocator.free(events);

    try std.testing.expectEqual(@as(usize, 3), events.len);
    try std.testing.expectEqual(@as(usize, 0), events[0].string);
    try std.testing.expectEqual(@as(usize, 1), events[1].string);
    try std.testing.expectEqual(@as(usize, 2), events[2].string);
}

test {
    std.testing.refAllDecls(@This());
}
