const std = @import("std");
const l = @import("lightmix");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const lightmix = b.dependency("lightmix", .{});

    // Modules
    const filters = b.createModule(.{
        .root_source_file = b.path("modules/filters/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const scale = b.createModule(.{
        .root_source_file = b.path("modules/scale/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    const sine = b.createModule(.{
        .root_source_file = b.path("modules/sine/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const splitter = b.createModule(.{
        .root_source_file = b.path("modules/splitter/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        },
    });

    const tempo = b.createModule(.{
        .root_source_file = b.path("modules/tempo/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{},
    });

    const imports: []const std.Build.Module.Import = &.{
        .{ .name = "lightmix", .module = lightmix.module("lightmix") },
        .{ .name = "filters", .module = filters },
        .{ .name = "scale", .module = scale },
        .{ .name = "sine", .module = sine },
        .{ .name = "splitter", .module = splitter },
        .{ .name = "tempo", .module = tempo },
    };
    const mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
        .imports = imports,
    });

    // System library linking on Linux
    if (target.result.os.tag == .linux) {
        mod.linkSystemLibrary("alsa", .{});
        mod.linkSystemLibrary("libpulse", .{});
        mod.linkSystemLibrary("libpipewire-0.3", .{});
    }

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
            .name = "coffee-chan.wav",
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

    // Sandbox
    const sandbox_step = b.step("sandbox", "Generate wav files on sandbox");
    try build_sandbox(b, target, optimize, imports, sandbox_step);
}

fn build_sandbox(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    imports: []const std.Build.Module.Import,
    sandbox_step: *std.Build.Step,
) !void {
    const paths_names: []const struct { []const u8, []const u8 } = &.{
        .{ "sandbox/sine/mono-440.0.zig", "sine-mono-440.0.wav" },
        .{ "sandbox/sine/stereo-440.0.zig", "sine-stereo-440.0.wav" },
        .{ "sandbox/scale/sine-a4.zig", "scale-sine-a4.wav" },
        .{ "sandbox/scale/sine-c4.zig", "scale-sine-c4.wav" },
    };

    inline for (paths_names) |pn| {
        const path = pn.@"0";
        const name = pn.@"1";

        const mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = imports,
        });

        const wave = try l.addWave(b, mod, .{
            .format = .{ .wav = .{
                .bits = 16,
                .format_code = .pcm,
                .name = name,
            } },
            .path = .{ .custom = "share/sandbox" },
        });
        sandbox_step.dependOn(wave.step);
    }
}
