const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    // Modules
    const sine = b.createModule(.{
        .root_source_file = b.path("modules/sine/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
            .{ .name = "sine", .module = sine },
        },
    });

    // Library installation
    const lib = b.addLibrary(.{
        .name = "coffee-chan",
        .root_module = mod,
        .linkage = .static,
    });
    b.installArtifact(lib);

    // Wave file installation
    const wave = try l.addWave(b, mod, .{
        .format = .{ .wav = .{
            .bits = 16,
            .format_code = .pcm,
        } },
    });
    l.installWave(b, wave);

    const play_step = b.step("play", "Play the produced Wave file");
    const play = try l.addPlay(b, wave, .{});
    play_step.dependOn(&play.step);

    // Tests
    const sine_tests = b.addTest(.{
        .root_module = sine,
    });
    const run_sine_tests = b.addRunArtifact(sine_tests);

    const mod_tests = b.addTest(.{
        .root_module = mod,
    });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    // Test step
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_sine_tests.step);
    test_step.dependOn(&run_mod_tests.step);
}
