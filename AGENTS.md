# AGENTS.md

Welcome to **coffee-chan**! This document provides guidelines, context, and operational instructions for AI agents working in this codebase.

______________________________________________________________________

## Project Overview

- **Name**: `coffee-chan`
- **Description**: A procedural cafe music generator written in Zig, built using the [lightmix](https://github.com/haruki7049/lightmix) audio library.
- **Language**: [Zig](https://ziglang.org/) (Version: `0.16.0`)
- **Environment**: Nix flake & nix-shell support
- **Output**: Generates PCM WAV audio files (primarily `coffee-chan.wav`) and a static library.

______________________________________________________________________

## Development Environment & Dependencies

- **Zig Version**: `0.16.0` (Environment managed via Nix Flakes: `pkgs.zig_0_16`).
- **Nix**: Flakes-enabled Nix environment.
- **System Libraries**:
  - Linux: ALSA (`libasound2` / `alsa-lib`) linked in `build.zig` (`mod.linkSystemLibrary("alsa", .{})`).
- **Tools in Nix Shell**:
  - `zig`, `zls` (Zig language server)
  - `treefmt` (code formatting)
  - `zon2nix` (translates `build.zig.zon` dependencies to Nix derivations)
  - `sox` (audio player utility `play`)

______________________________________________________________________

## Essential Commands

All commands can be executed in the Nix development environment (`nix develop` or `nix-shell`).

### Build & Generate Audio

```sh
# Build static library and generate coffee-chan.wav (in zig-out/share/)
zig build

# Build via Nix
nix build --print-build-logs
```

### Run Tests

```sh
# Run all unit tests across modules and root
zig build test
```

### Play Audio

```sh
# Play the generated audio file
zig build play
```

### Sandbox & Experiments

```sh
# Generate test/prototype wav files in sandbox (outputs to zig-out/share/sandbox/)
zig build sandbox
```

### Code Formatting

```sh
# Format all supported files (Zig, Nix, Markdown, Actions, Shell)
treefmt

# Format Zig files directly
zig fmt <file_or_dir>
```

### Updating Dependencies

When modifying dependencies in `build.zig.zon`:

```sh
# Re-generate .deps.nix for Nix builds
zon2nix > .deps.nix
```

______________________________________________________________________

## Project Architecture & Directory Structure

```
coffee-chan/
├── src/
│   └── root.zig               # Main entry point; exports `gen()` to create the final wave
├── modules/
│   ├── filters/               # Audio DSP filters (decay, normalize, etc.)
│   ├── phrases/               # Musical phrases and sequence compositions (_0000, _0001, _0002, etc.)
│   ├── synthesizers/          # Sound generator engines (sine, whitenoise, karplus-strong, etc.)
│   └── utils/                 # Audio & music theory helpers (scale/frequencies, tempo/spb, splitter)
├── sandbox/                   # Prototyping and audio experiment Zig scripts
├── build.zig                  # Zig build definition and module wiring
├── build.zig.zon              # Zig package manifest and dependencies (lightmix)
├── flake.nix / default.nix    # Nix build and flake definition
├── .deps.nix                  # Generated Nix dependencies for Zig packages
└── .github/workflows/         # CI/CD workflows (release on tag push)
```

### Module Responsibilities

1. **`src/root.zig`**:

   - Implements `pub fn gen(allocator: std.mem.Allocator) !lightmix.Wave(T)`.
   - Defines composition parameters (BPM, sample rate, channels, master volume).
   - Combines generated phrases and applies master filters (e.g. `filters.normalize`).

1. **`modules/filters/`**:

   - DSP filters applied to `lightmix.Wave(T)`.
   - Examples: `decay.zig`, `normalize.zig`.
   - Re-exported through `modules/filters/root.zig`.

1. **`modules/phrases/`**:

   - High-level musical phrases (e.g., `_0000`, `_0001`, `_0002`).
   - Assembles synths, scales, and rhythms into distinct musical sections.
   - Re-exported through `modules/phrases/root.zig`.

1. **`modules/synthesizers/`**:

   - Synthesizer engines producing raw sound waves.
   - Examples:
     - `sine`: Pure sinusoidal tone generator.
     - `karplus-strong`: Plucked-string physical modeling synthesizer with damping and excitation LPF.
     - `whitenoise`: Noise generator.
   - Re-exported through `modules/synthesizers/root.zig`.

1. **`modules/utils/`**:

   - Helper calculations for music production.
   - Examples:
     - `scale`: Note code to frequency calculation (equal temperament).
     - `tempo`: Beats per minute to samples per beat (`spb`) conversion.
     - `splitter`: Channel splitting and stereo routing.

______________________________________________________________________

## Coding Guidelines & Conventions

### 1. Zig Idioms & Conventions

- **Naming**:
  - Types / Structs / Enums / Modules: `PascalCase` (e.g., `KarplusStrong`, `Scale`, `Wave`).
  - Functions / Variables / Fields: `snake_case` (e.g., `sample_rate`, `filter_weight`).
  - Constants / Config: `SCREAMING_SNAKE_CASE` or `snake_case` depending on context (BPM, SAMPLE_RATE).
- **Generics**:
  - Wave sample type is parameterized using `comptime T: type` (usually `f64`).
- **Memory Allocation**:
  - Always accept `allocator: std.mem.Allocator` explicitly when buffers or waves are allocated.
  - Ensure all allocated resources are either returned or freed on error (`errdefer`).
- **Error Unions**:
  - Functions performing dynamic allocation or I/O must return error unions (e.g., `!lightmix.Wave(T)`).

### 2. Module Registration

- When adding a new synthesizer, filter, or utility:
  1. Place implementation in the appropriate subdirectory under `modules/<category>/<feature>/`.
  1. Create or update `root.zig` within that subfolder.
  1. Export the new feature in `modules/<category>/root.zig`.
  1. Include a `test` block with `std.testing.refAllDecls(@This());` in each `root.zig`.
  1. If necessary, expose in `build.zig` module imports or test runner.

### 3. Testing & Validation Rules

- **Run Tests**: Always verify changes by running `zig build test`.
- **Verify Build**: Always run `zig build` to verify that `coffee-chan.wav` compiles successfully without regressions.
- **Code Style**: Run `treefmt` (or `zig fmt`) on any modified files before committing.
- **Dependency Hygiene**: Do not introduce unvetted external dependencies. Keep dependencies pinned.

### 4. Git & Development Workflow

- **Branch Creation**:
  - Always create a new feature branch branching off from `main` (never commit directly to `main`).
  - Example: `git switch -c feature/<topic-name>`
- **Verification**:
  - Run `zig build test` and `zig build` to verify all changes.
  - Run `treefmt` to format code before committing.
- **Pull Requests**:
  - Push the feature branch to origin and open a Pull Request targeting `main` as the base branch.
