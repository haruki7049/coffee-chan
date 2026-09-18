______________________________________________________________________

## name: pr-workflow description: >- Use this skill when creating commits, preparing Pull Requests (PRs), formatting code, and executing pre-submission verification steps for coffee-chan.

# Pull Request & Commit Workflow for `coffee-chan`

This skill defines the procedures for code verification, commit creation, and pull request submission.

## 1. Mandatory Verification Steps

Before committing or opening a PR, execute the following commands and ensure all pass cleanly:

| Task | Command | Description |
| :--- | :--- | :--- |
| **Check All Formatting (treefmt)** | `treefmt --fail-on-change` | Verifies formatting across Zig, Nix, Markdown, and Shell files |
| **Format All Files (treefmt)** | `treefmt` | Auto-formats all files in the repository using treefmt |
| **Run All Tests** | `zig build test` | Executes unit tests for modules and root |
| **Build WAV Output** | `zig build` | Compiles project and generates `coffee-chan.wav` |
| **Generate Sandbox Audio** | `zig build sandbox` | Generates WAV files for experimental sandbox scripts |

## 2. Commit & PR Title Conventions

Use Conventional Commits style prefixes:

- `feat:` New synthesizer, phrase, filter, or major capability.
- `fix:` Bug fixes or corrections to audio synthesis/build logic.
- `build:` Updates to `build.zig`, `build.zig.zon`, `flake.nix`, or dependencies (`lightmix`).
- `refactor:` Code restructuring without changing output logic.
- `docs:` Updates to README, AGENTS.md, or code documentation.
- `test:` Adding or updating unit/integration tests.

## 3. PR Description Requirements

Ensure the PR description includes:

- **Summary**: Concise overview of changes.
- **Verification**: Explicitly list executed verification commands (`treefmt --fail-on-change`, `zig build test`, etc.) and their success status.
- **Breaking Changes**: Highlight any breaking changes to modules or dependencies.

## 4. Strict Safety & Approval Rules

- **NEVER AUTO-MERGE TO MAIN**: AI agents **MUST NEVER** merge PRs, execute `git merge`, or directly push commits to the `main` branch autonomously.
- **Mandatory Human Approval**: AI agents may create branches, propose PRs, format code, and run test suites, but the final action of merging changes into `main` rests strictly with the human maintainer.
