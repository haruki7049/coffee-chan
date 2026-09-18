const std = @import("std");

pub const Position = @import("position.zig");
pub const TimeSignature = @import("time_signature.zig");
pub const Event = @import("event.zig").inner;
pub const Track = @import("track.zig").inner;
pub const Instrument = @import("instrument.zig").inner;
pub const VoiceScheduler = @import("voice_scheduler.zig").inner;
pub const Sequencer = @import("sequencer.zig").inner;

test {
    std.testing.refAllDecls(@This());
    _ = Position;
    _ = TimeSignature;
    _ = @import("event.zig");
    _ = @import("track.zig");
    _ = @import("instrument.zig");
    _ = @import("voice_scheduler.zig");
    _ = @import("sequencer.zig");
}
