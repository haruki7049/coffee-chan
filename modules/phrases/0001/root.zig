const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const Scale = utils.scale.Scale;
const KarplusStrong = synthesizers.karplus_strong.KarplusStrong;
const spb = utils.tempo.spb;

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    bpm: usize,
    sample_rate: u32,
    channels: u16,
    volume: T,
) !lightmix.Wave(T) {
    const frequency: T = Scale.gen(.{ .code = .c, .octave = 4 });
    const length: usize = spb(bpm, sample_rate);

    const sound: lightmix.Wave(T) = try KarplusStrong.gen(T, allocator, frequency, sample_rate, channels, length, volume, .{});
    return sound;
}

test {
    std.testing.refAllDecls(@This());
}
