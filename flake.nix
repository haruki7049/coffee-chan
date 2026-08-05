{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-compat.url = "github:edolstra/flake-compat";
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];

      imports = [
        inputs.treefmt-nix.flakeModule
      ];

      perSystem =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          buildInputs = lib.optionals pkgs.stdenv.isLinux [
            pkgs.alsa-lib
            pkgs.pulseaudio
            pkgs.pipewire
          ];

          ZIG = pkgs.zig_0_15;
          nativeBuildInputs = [
            # Compiler
            ZIG
            pkgs.pkg-config

            # LSP
            pkgs.nil
            pkgs.zls

            # Music Player
            pkgs.sox # Use this command as: `play result.wav`

            # zon2nix
            pkgs.zon2nix
          ];

          coffee-chan = pkgs.stdenv.mkDerivation {
            name = "coffee-chan";
            src = lib.cleanSource ./.;
            doCheck = true;

            nativeBuildInputs = nativeBuildInputs ++ [ ZIG.hook ];
            inherit buildInputs;

            postPatch = ''
              ln -s ${pkgs.callPackage ./.deps.nix { }} $ZIG_GLOBAL_CACHE_DIR/p

              # Remove NIX_CFLAGS_COMPILE because zig cannot understand it
              unset NIX_CFLAGS_COMPILE
            '';
          };
        in
        {
          treefmt = {
            projectRootFile = ".git/config";

            # Nix
            programs.nixfmt.enable = true;

            # Zig
            programs.zig.enable = true;
            settings.formatter.zig.command = lib.getExe pkgs.zig_0_15;

            # GitHub Actions
            programs.actionlint.enable = true;

            # Markdown
            programs.mdformat.enable = true;

            # Shell Scripts
            programs.shellcheck.enable = true;
            programs.shfmt.enable = true;
          };

          packages = {
            inherit coffee-chan;
            default = coffee-chan;
          };

          checks = {
            inherit coffee-chan;
          };

          devShells.default = pkgs.mkShell {
            inherit nativeBuildInputs buildInputs;

            inputsFrom = [
              config.treefmt.build.devShell
            ];

            shellHook = ''
              # Remove NIX_CFLAGS_COMPILE because zig cannot understand it
              unset NIX_CFLAGS_COMPILE
            '';
          };
        };
    };
}
