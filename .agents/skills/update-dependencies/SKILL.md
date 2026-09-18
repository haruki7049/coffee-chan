______________________________________________________________________

## name: update-dependencies description: >- Use this skill when updating external Zig package dependencies (such as lightmix), synchronizing Nix lockfiles (.deps.nix via zon2nix), or modifying build.zig.zon.

# External Dependency Update Workflow (`lightmix`)

When updating external dependencies such as `lightmix`, both `build.zig.zon` and `.deps.nix` must be kept in sync:

1. **Update `build.zig.zon`**: Update the `url` (and package hash) under `.dependencies.lightmix`.
1. **Synchronize Nix Lockfile**: Run `zon2nix > .deps.nix` to regenerate the Nix dependency lockfile `.deps.nix`.
1. **Format Code**: Run `treefmt` to format all changed files (including `.deps.nix` and `build.zig.zon`).
1. **Verification**: Run `zig build`, `zig build test`, and `zig build sandbox` to guarantee error-free compilation and execution.
