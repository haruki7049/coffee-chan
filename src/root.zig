const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");
const utils = @import("utils");
const synthesizers = @import("synthesizers");

const T = f64;
const Scale = utils.scale.Scale;
const Sine = synthesizers.sine.Sine;
const Splitter = utils.splitter.Splitter;
const spb = utils.tempo.spb;

pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T) {
    const BPM: usize = 60;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var result: lightmix.Wave(T) = try phrases._0000.gen(T, allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    try filters.normalize(T, &result, 1.0);
    return result;
}
