const std = @import("std");
const lightmix = @import("lightmix");

pub const Error = std.mem.Allocator.Error || error{
    EmptyWaves,
};

pub fn gen(
    comptime T: type,
    allocator: std.mem.Allocator,
    length: usize,
    waves: []const ?lightmix.Wave(T),
    sample_rate: u32,
    channels: u16,
) !lightmix.Wave(T) {
    if (waves.len == 0) return error.EmptyWaves;

    var composer = try lightmix.Composer(T).init(allocator, .{
        .channels = channels,
        .sample_rate = sample_rate,
    });
    defer composer.deinit();

    // Get an interval for each Wave
    const interval: usize = length / waves.len;

    // Adds each wave to the composer
    var intervals: usize = 0;
    for (waves) |wave| {
        if (wave != null) {
            try composer.append(.{ .wave = wave.?, .start_point = intervals * channels });
        }

        intervals += interval;
    }

    // Finalize
    const result: lightmix.Wave(T) = try composer.finalize(.{});
    return result;
}

test "splitter gen splits waves at intervals" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 100);
    @memset(samples, 0.5);

    const sound = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer sound.deinit();

    var wave = try gen(f64, allocator, 400, &.{ sound, null }, 44100, 2);
    defer wave.deinit();

    try std.testing.expect(wave.samples.len > 0);
    try std.testing.expectEqual(@as(u16, 2), wave.channels);
    try std.testing.expectEqual(@as(u32, 44100), wave.sample_rate);
}

test "splitter gen empty waves returns error.EmptyWaves" {
    const allocator = std.testing.allocator;
    try std.testing.expectError(error.EmptyWaves, gen(f64, allocator, 400, &.{}, 44100, 2));
}
