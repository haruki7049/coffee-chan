const std = @import("std");
const lightmix = @import("lightmix");

pub const Error = std.mem.Allocator.Error || error{
    EmptyWave,
    InvalidChannels,
};

pub fn inner(comptime T: type, target: *lightmix.Wave(T)) Error!void {
    if (target.channels == 0) return error.InvalidChannels;
    if (target.samples.len == 0) return error.EmptyWave;

    const total_frames = target.samples.len / target.channels;
    if (total_frames == 0) return error.EmptyWave;

    const allocator = target.allocator;
    const sample_rate = target.sample_rate;
    const channels = target.channels;

    var samples = try allocator.alloc(T, target.samples.len);

    // Process each audio frame, applying decay synchronously across all channels
    for (0..total_frames) |frame| {
        const remaining_frames = total_frames - frame;
        const decay_factor = @as(T, @floatFromInt(remaining_frames)) /
            @as(T, @floatFromInt(total_frames));

        for (0..channels) |ch| {
            const idx = frame * channels + ch;
            samples[idx] = target.samples[idx] * decay_factor;
        }
    }

    // Free original samples on target variable
    target.allocator.free(target.samples);

    target.allocator = allocator;
    target.samples = samples;
    target.sample_rate = sample_rate;
    target.channels = channels;
}

test "decay filter" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4);
    samples[0] = 1.0;
    samples[1] = 1.0;
    samples[2] = 1.0;
    samples[3] = 1.0;

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 1,
    };
    defer wave.deinit();

    try inner(f64, &wave);

    try std.testing.expectApproxEqAbs(@as(f64, 1.0), wave.samples[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.75), wave.samples[1], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), wave.samples[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.25), wave.samples[3], 1e-6);
}

test "decay filter stereo preserves channel balance" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4); // 2 frames of stereo
    samples[0] = 1.0; // L0
    samples[1] = 1.0; // R0
    samples[2] = 1.0; // L1
    samples[3] = 1.0; // R1

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try inner(f64, &wave);

    // Frame 0 (remaining 2/2 = 1.0)
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), wave.samples[0], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 1.0), wave.samples[1], 1e-6);
    // Frame 1 (remaining 1/2 = 0.5)
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), wave.samples[2], 1e-6);
    try std.testing.expectApproxEqAbs(@as(f64, 0.5), wave.samples[3], 1e-6);
}

test "decay filter empty buffer returns error.EmptyWave" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 0);

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 2,
    };
    defer wave.deinit();

    try std.testing.expectError(error.EmptyWave, inner(f64, &wave));
}

test "decay filter zero channels returns error.InvalidChannels" {
    const allocator = std.testing.allocator;
    const samples = try allocator.alloc(f64, 4);

    var wave = lightmix.Wave(f64){
        .allocator = allocator,
        .samples = samples,
        .sample_rate = 44100,
        .channels = 0,
    };
    defer wave.deinit();

    try std.testing.expectError(error.InvalidChannels, inner(f64, &wave));
}
