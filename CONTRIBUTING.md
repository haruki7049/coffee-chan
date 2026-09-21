# Contributing Guide for `coffee-chan`

Thank you for contributing to `coffee-chan`! This document outlines the development guidelines, setup instructions, and code verification workflow for contributors.

______________________________________________________________________

## 1. Project Overview & Architecture

`coffee-chan` is a deterministic cafe music generation project built using Zig `0.16.0` and the [`lightmix`](https://github.com/haruki7049/lightmix) audio synthesis library.

- **Deterministic Music Generation**: Running build steps generates `.wav` audio files directly during the build process without real-time recording.
- **Modular Audio Architecture**: Code is structured into reusable modules under `modules/` (see [Module Layering](#module-layering)) and integrated in `src/root.zig`.
- **Sandbox Environment**: Experimental synthesizers, scales, and audio prototypes reside in `sandbox/`.

______________________________________________________________________

## 2. Development Environment Setup

We manage project dependencies using **Nix**, **direnv**, and **nix-direnv** for reproducible development environments.

### Prerequisites

- [Nix](https://nixos.org/download.html) with Flakes enabled
- [direnv](https://direnv.net/)

### Quick Start

```bash
# Clone the repository
git clone https://github.com/haruki7049/coffee-chan.git
cd coffee-chan

# Allow direnv to load the Nix development shell automatically
direnv allow
```

Once inside the environment, all required tools (`zig`, `treefmt`, `zon2nix`, etc.) are automatically placed in your path.

______________________________________________________________________

## 3. Repository Structure

- `src/`: Main entry point (`root.zig`) for composing full tracks.
- `modules/`: Reusable audio synthesis building blocks:
  - `filters/`: Audio filters (e.g., normalization, gain).
  - `phrases/`: The `Phrase` type, `Bind` and the phrase score data.
  - `synthesizers/`: Sound generators (e.g., Karplus-Strong, Sine).
  - `music/`: Music primitives (note, scale, tempo, position, time signature).
  - `sequencer/`: Song-independent playback engine (sequencer, tracks, renderer).
  - `banks/`: Song-specific sound caches (`DrumBank`, `PhraseBank`, `cache`).
- `sandbox/`: Experimental scripts for audio prototyping.
- `.github/workflows/`: CI/CD automation workflows.

### Module Layering

Modules form a strict layering: a module may depend only on modules in lower layers, never on the same layer or above. The layout is:

| Layer | Module | Contents | Depends on |
| :--- | :--- | :--- | :--- |
| 0 | `filters` | Audio filters (`decay`, `normalize`) | `lightmix` |
| 0 | `synthesizers` | Sound generators (one directory per synthesizer) | `lightmix` |
| 1 | `music` | Music primitives: `note`, `scale`, `tempo`, `Position`, `TimeSignature` | `lightmix` |
| 2 | `sequencer` | Song-independent playback engine: `Sequencer`, `Track`, `Instrument`, `Event`, `Renderer`, `VoiceScheduler`, `Stagger` | `music`, `lightmix` |
| 3 | `phrases` | The `Phrase` type, `Bind` and the phrase score data | `music`, `sequencer`, `synthesizers`, `lightmix` |
| 4 | `banks` | Song-specific sound caches: `DrumBank`, `PhraseBank` and the generic `cache` | `music`, `phrases`, `sequencer`, `synthesizers`, `filters`, `lightmix` |
| 5 | `src/` | `gen` and `Composition`, the arrangement of the whole song | all modules |

Rules:

- **No catch-all module**: a module such as `utils` is not allowed. Every piece of code belongs to a module with a single responsibility.
- **`sequencer` stays song-independent**: it must not import `synthesizers`, `filters`, `phrases` or `banks`, so it can be reused for another song.
- **`banks` is the only place that knows both the score and the sound**: it caches generated waves; placing them on the timeline is the job of `sequencer`.
- **`filters` and `synthesizers` stay separate**: both use one directory per unit with a `root.zig`.
- **Synthesizer `gen` shapes**: pitched synthesizers take `frequency` (`gen(T, allocator, frequency, sample_rate, channels, length, volume, options)`); unpitched ones (`whitenoise`, `vinyl_noise`) do not take it. See the doc comment in `modules/synthesizers/root.zig`.

______________________________________________________________________

## 4. Mandatory Verification Workflow

Before creating a Pull Request, you **MUST** run all verification commands and ensure clean execution:

| Command | Purpose |
| :--- | :--- |
| `treefmt` | Formats all files across Zig, Nix, Markdown, and Shell |
| `treefmt --fail-on-change` | Checks formatting compliance across all project files |
| `zig build` | Compiles the main project and generates `coffee-chan.wav` |
| `zig build test` | Executes unit test suites across all modules and root |
| `zig build sandbox` | Generates WAV outputs for experimental sandbox scripts |

______________________________________________________________________

## 5. Naming Conventions

All code symbols, directory layouts, music track arrangements, Git branches, and commit messages follow our centralized naming standards. Please refer to [Naming Conventions](docs/NAMING.md) for detailed rules and examples before submitting contributions.

______________________________________________________________________

## 6. Pull Request Guidelines

1. **Format & Test Verification**: Ensure `treefmt --fail-on-change`, `zig build`, `zig build test`, and `zig build sandbox` all pass cleanly.
1. **Conventional Commits**: Use conventional commit prefixes (`feat:`, `fix:`, `docs:`, `refactor:`, `build:`, `test:`, `ci:`).
1. **PR Description**: Include a clear summary of changes, an explicit issue-closing keyword (e.g., `Closes #123`), and confirmation of completed verification commands.
