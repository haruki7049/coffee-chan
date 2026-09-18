# Contributing Guide for `coffee-chan`

Thank you for contributing to `coffee-chan`! This document outlines the development guidelines, setup instructions, and code verification workflow for contributors.

______________________________________________________________________

## 1. Project Overview & Architecture

`coffee-chan` is a deterministic cafe music generation project built using Zig `0.16.0` and the [`lightmix`](https://github.com/haruki7049/lightmix) audio synthesis library.

- **Deterministic Music Generation**: Running build steps generates `.wav` audio files directly during the build process without real-time recording.
- **Modular Audio Architecture**: Code is structured into reusable modules under `modules/` (`filters`, `phrases`, `synthesizers`, `utils`) and integrated in `src/root.zig`.
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
  - `utils/`: Pitch, scale, tempo, and helper utilities.
- `sandbox/`: Experimental scripts for audio prototyping.
- `.github/workflows/`: CI/CD automation workflows.

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
