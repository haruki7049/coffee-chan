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
  - `phrases/`: Score logic and phrase arrangements.
  - `synthesizers/`: Sound generators (e.g., Karplus-Strong, Sine).
  - `music/`: Music primitives (note, scale, tempo, position, time signature).
  - `sequencer/`: Song-independent playback engine (sequencer, tracks, renderer).
  - `utils/`: Not yet migrated code (`cache`, `phrase`); see Module Layering.
- `sandbox/`: Experimental scripts for audio prototyping.
- `.github/workflows/`: CI/CD automation workflows.

### Module Layering

Modules form a strict layering: a module may depend only on modules in lower layers, never on the same layer or above. The target layout is:

| Layer | Module | Contents | Depends on |
| :--- | :--- | :--- | :--- |
| 0 | `filters` | Audio filters (`decay`, `normalize`) | `lightmix` |
| 0 | `synthesizers` | Sound generators (one directory per synthesizer) | `lightmix` |
| 1 | `music` | Music primitives: `note`, `scale`, `tempo`, `Position`, `TimeSignature` | `lightmix` |
| 2 | `sequencer` | Song-independent playback engine: `Sequencer`, `Track`, `Instrument`, `Event`, `Renderer`, `VoiceScheduler`, `Stagger` | `music`, `lightmix` |
| 3 | `phrases` | The `Phrase` type, `Bind` and the phrase score data | `music`, `sequencer`, `synthesizers` |
| 4 | `banks` | Song-specific sound caches: `DrumBank`, `PhraseBank` and the generic `cache` | `phrases`, `sequencer`, `synthesizers`, `filters` |
| 5 | `src/` | `gen` and `Composition`, the arrangement of the whole song | all modules |

Rules:

- **No `utils`**: a catch-all module is not allowed. Every piece of code belongs to a module with a single responsibility.
- **`sequencer` stays song-independent**: it must not import `synthesizers`, `filters`, `phrases` or `banks`, so it can be reused for another song.
- **`banks` is the only place that knows both the score and the sound**: it caches generated waves; placing them on the timeline is the job of `sequencer`.
- **`filters` and `synthesizers` stay separate**: both use one directory per unit with a `root.zig`.

The repository is migrating from the current layout (`utils` still holds `cache` and `phrase`; `music` and `sequencer` are already extracted) to this layout. Each step is tracked by its own Issue and must keep the generated `coffee-chan.wav` byte-identical:

1. Move `Position` and `TimeSignature` out of `sequencer`, and make `note` stop depending on `sequencer` (the only reverse dependency today) (#165).
1. ~~Extract `note`, `scale`, `tempo`, `Position` and `TimeSignature` into the `music` module (#166).~~ Done.
1. ~~Extract `sequencer` into its own module (#167).~~ Done.
1. Move `Phrase` and `Bind` from `utils.phrase` into the `phrases` module (#168).
1. Create the `banks` module with `DrumBank`, `PhraseBank` and `cache` (#169).
1. Remove `utils`, and update this document and `build.zig` to match (#170).
1. ~~Align `filters` with the one-directory-per-unit layout (#171).~~ Done.

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
