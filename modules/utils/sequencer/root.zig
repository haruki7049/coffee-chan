const std = @import("std");

pub const Position = @import("position.zig");
pub const TimeSignature = @import("time-signature.zig");
pub const Event = @import("event.zig").inner;
pub const Track = @import("track.zig").inner;
pub const Instrument = @import("instrument.zig").inner;
pub const VoiceScheduler = @import("voice-scheduler.zig").inner;
pub const Renderer = @import("renderer.zig").inner;
pub const StreamOptions = @import("renderer.zig").StreamOptions;
pub const Sequencer = @import("sequencer.zig").inner;
pub const Stagger = @import("stagger.zig");

test {
    std.testing.refAllDecls(@This());
    _ = Position;
    _ = TimeSignature;
    _ = @import("event.zig");
    _ = @import("track.zig");
    _ = @import("instrument.zig");
    _ = @import("voice-scheduler.zig");
    _ = @import("renderer.zig");
    _ = @import("sequencer.zig");
    _ = Stagger;
}
