const std = @import("std");
const lightmix = @import("lightmix");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const T = f64;
const Scale = utils.scale.Scale;
const Sine = synthesizers.sine.Sine;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const FREQUENCY: T = Scale.gen(.{ .code = .a, .octave = 4 });
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const LENGTH: usize = SAMPLE_RATE * 2;
    const VOLUME: T = 1.0;

    const sine_a4: lightmix.Wave(T) = try Sine.gen(T, allocator, FREQUENCY, SAMPLE_RATE, CHANNELS, LENGTH, VOLUME);
    return sine_a4;
}
