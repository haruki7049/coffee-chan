# coffee-chan

Deterministically generated cafe music synthesized with Zig and the [`lightmix`](https://github.com/haruki7049/lightmix) audio synthesis library.

## Overview

`coffee-chan` treats music composition as a deterministic build artifact. Running `zig build` or `zig build play` synthesizes WAV audio files directly during the build step, eliminating real-time recording requirements.

## Quick Start

### Play & Generate Audio

```sh
# Generate and immediately play the WAV output
zig build play

# Build coffee-chan.wav (output in zig-out/share/coffee-chan.wav)
zig build
```

### Build with Nix

```sh
# Enter reproducible development shell
direnv allow # or nix-shell

# Build package via Nix Flakes
nix build
```

## Requirements

- **Zig**: `0.16.0`
- **Library**: [`lightmix`](https://github.com/haruki7049/lightmix)

## License

Dual-licensed under Apache-2.0 or MIT.
