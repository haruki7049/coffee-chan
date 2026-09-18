# Agent Guidelines for `coffee-chan`

This document defines core principles, architectural invariants, and non-negotiable safety rules for AI agents working on the `coffee-chan` repository.

______________________________________________________________________

## 1. Project Overview & Architecture

`coffee-chan` is a cafe music generation project built with the [`lightmix`](https://github.com/haruki7049/lightmix) audio synthesis library in Zig.

- **Deterministic Generation**: Music generation is treated as a deterministic build artifact. Running `zig build` produces `coffee-chan.wav` directly during the build.
- **Development Environment**: Managed with Nix, `direnv`, and `nix-direnv` for automated environment isolation. Formatting across all languages is handled via `treefmt`.
- **Target Language Version**: Zig `0.16.0`. Avoid unnecessary external dependencies to maintain seamless cross-compilation.
- **Modular Directory Structure**:
  - `src/root.zig`: Main music composition and build-time generation entry point.
  - `modules/`: Reusable audio modules (`filters`, `phrases`, `synthesizers`, `utils`).
  - `sandbox/`: Prototyping directory for testing synthesizers and scales independently.
  - `build.zig` & `build.zig.zon`: Build definition and package metadata.

______________________________________________________________________

## 2. Strict Safety & Contribution Rules (Always Enforced)

- **NEVER AUTO-MERGE TO MAIN**: AI agents **MUST NEVER** merge PRs, execute `git merge`, or directly push commits to the `main` branch autonomously.
- **Mandatory Human Approval**: AI agents may create branches, propose PRs, format code, and run test suites, but the final action of merging changes into `main` rests strictly with the human maintainer.
- **Verification Before Submitting**: All changes must pass `treefmt --fail-on-change`, `zig build`, and `zig build test`.
- **Conventional Commits**: Use conventional commit prefixes (`feat:`, `fix:`, `refactor:`, `docs:`, `build:`, `test:`).

______________________________________________________________________

## 3. Workspace Skills

Detailed runbooks and procedural workflows are maintained as workspace skills under `.agents/skills/`:

- **[`update-dependencies`](.agents/skills/update-dependencies/SKILL.md)**: Procedures for bumping `lightmix` and synchronizing `.deps.nix` via `zon2nix`.
- **[`pr-workflow`](.agents/skills/pr-workflow/SKILL.md)**: Pre-submission verification command table, PR template requirements, and commit conventions.
