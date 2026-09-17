const std = @import("std");
const lightmix = @import("lightmix");
const filters = @import("filters");
const phrases = @import("phrases");

const T = f64;

pub fn gen(init: std.process.Init) !lightmix.Wave(T) {
    const allocator: std.mem.Allocator = init.arena.allocator();

    const BPM: usize = 60;
    const SAMPLE_RATE: u32 = 44100;
    const CHANNELS: u16 = 2;
    const VOLUME: T = 1.0;

    var result: lightmix.Wave(T) = try phrases._0002.gen(T, allocator, BPM, SAMPLE_RATE, CHANNELS, VOLUME);
    try filters.normalize(T, &result, 1.0);
    return result;
}
