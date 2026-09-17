# Agent Guidelines for `coffee-chan`

This document provides context, instructions, and conventions for AI agents (such as Antigravity, Gemini, Claude, Cursor, ChatGPT, etc.) working on the `coffee-chan` repository.

______________________________________________________________________

## 1. Project Overview

`coffee-chan` is a cafe music generation project built with the [`lightmix`](https://github.com/haruki7049/lightmix) audio synthesis library in Zig.

- **Core Philosophy**: Treat music generation as a deterministic build artifact. Running `zig build` or `zig build play` produces WAV audio files directly during the build process, eliminating real-time recording requirements.
- **Development Environment**: Managed with Nix, `direnv`, and `nix-direnv` for automated environment isolation. Code formatting across the repository (Zig, Nix, Markdown, Shell, GitHub Actions) is handled via `treefmt`.
- **Architectural Principles & Scope**:
  - **Modular Audio Design**: Code is structured into reusable modules under `modules/` (`filters`, `phrases`, `synthesizers`, `utils`) and assembled in `src/root.zig`.
  - **Deterministic Generation**: Uses `lightmix` primitives and caller-provided parameters to guarantee identical WAV output across builds.
  - **Experimental Sandbox**: Prototypes for synthesizers, scales, and audio experiments belong in `sandbox/`.
  - **Pure Zig & Cross-Platform**: Avoid unnecessary external dependencies where possible, keeping cross-compilation seamless.
- **Target Language Version**: Zig `0.16.0`.

______________________________________________________________________

## 2. Directory Structure

- `src/`
  - `root.zig`: Main music composition and entry point.
- `modules/`
  - `filters/`: Audio filter implementations.
  - `phrases/`: Musical phrase arrangements and score logic.
  - `synthesizers/`: Sound synthesis algorithms (e.g., Karplus-Strong, Sine generators).
  - `utils/`: Common helpers for music theory, scale calculations, and conversion.
- `sandbox/`: Prototyping directory for testing synthesizers and scales independently (`karplus-strong`, `scale`, `sine`).
- `build.zig` & `build.zig.zon`: Build definition script and package metadata (configured with `lightmix` dependency).
- `flake.nix`, `shell.nix`, `default.nix`, `.envrc`: Nix development shell configurations and `direnv` integration.

______________________________________________________________________

## 3. Mandatory Commands & Verification Workflow

Before marking any task as complete, AI agents **MUST** execute the relevant commands below and verify clean execution:

| Task | Command | Description |
| :--- | :--- | :--- |
| **Build WAV Output** | `zig build` | Compiles project and generates `coffee-chan.wav` |
| **Run All Tests** | `zig build test` | Executes unit tests for modules and root |
| **Generate Sandbox Audio** | `zig build sandbox` | Generates WAV files for experimental sandbox scripts |
| **Play Produced WAV** | `zig build play` | Plays the generated WAV file |
| **Check All Formatting (treefmt)** | `treefmt --fail-on-change` | Verifies formatting for all files (Zig, Nix, Markdown, Shell, etc.) |
| **Format All Files (treefmt)** | `treefmt` | Auto-formats all files in the repository using treefmt |
| **Check Zig Formatting** | `zig fmt --check .` | Verifies code formatting for Zig files |
| **Format Zig Code** | `zig fmt .` | Auto-formats Zig code |

______________________________________________________________________

## 4. Pull Request & Commit Guidelines

When creating Pull Requests (PRs) or submitting commits, agents **MUST** follow these rules:

1. **Mandatory Verification Before Submitting**:

   - Run `treefmt --fail-on-change` to confirm all formatting passes cleanly across Zig, Nix, Markdown, and Shell files.
   - Run `zig build` and `zig build test` to guarantee error-free compilation and test execution.
   - Run `zig build sandbox` if sandbox scripts or modules were affected.

1. **Commit & PR Title Conventions**:

   - Use Conventional Commits style prefixes:
     - `feat:` New synthesizer, phrase, filter, or major capability.
     - `fix:` Bug fixes or corrections to audio synthesis/build logic.
     - `build:` Updates to `build.zig`, `build.zig.zon`, `flake.nix`, or dependencies (`lightmix`).
     - `refactor:` Code restructuring without changing output logic.
     - `docs:` Updates to README, AGENTS.md, or code documentation.
     - `test:` Adding or updating unit/integration tests.

1. **PR Description Requirements**:

   - **Summary**: Concise overview of changes.
   - **Verification**: Explicitly list executed verification commands (`treefmt --fail-on-change`, `zig build test`, etc.) and their success status.
   - **Breaking Changes**: Highlight any breaking changes to modules or dependencies.

1. **Strict Safety & Approval Rules (No Automated Merging to `main`)**:

   - **NEVER AUTO-MERGE TO MAIN**: AI agents **MUST NEVER** merge PRs, execute `git merge`, or directly push commits to the `main` branch autonomously.
   - **Mandatory Human Approval**: AI agents may create branches, propose PRs, format code, and run test suites, but the final action of merging changes into `main` rests strictly with the human maintainer.
