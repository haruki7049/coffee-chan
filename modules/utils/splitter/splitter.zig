const std = @import("std");
const lightmix = @import("lightmix");

const Error = std.mem.Allocator.Error;

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    length: usize,
    waves: []const ?lightmix.Wave(T),
    sample_rate: u32,
    channels: u16,
) Error!lightmix.Wave(T) {
    var composer = lightmix.Composer(T).init(allocator, .{
        .channels = channels,
        .sample_rate = sample_rate,
    });
    defer composer.deinit();

    // Get a interval for each Wave
    const interval: usize = length / waves.len;

    // Adds each wave to the `var composer`
    var intervals: usize = 0;
    for (waves) |wave| {
        if (wave != null) {
            try composer.append(.{ .wave = wave.?, .start_point = intervals });
        }

        intervals += interval;
    }

    // Finalize
    const result: lightmix.Wave(T) = try composer.finalize(.{});
    return result;
}
