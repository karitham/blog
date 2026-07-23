{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };
  outputs =
    { nixpkgs, ... }:
    let
      forEachSupportedSystem =
        f:
        nixpkgs.lib.genAttrs [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ] (
          system: f { pkgs = import nixpkgs { inherit system; }; }
        );

      formatters = { pkgs }: [
        pkgs.gleam
        pkgs.nixfmt
        pkgs.rustfmt
        pkgs.taplo
        pkgs.shfmt
        pkgs.nufmt
        pkgs.prettier
      ];
    in
    {
      formatter = forEachSupportedSystem (
        { pkgs }:
        pkgs.writeShellScriptBin "treefmt-wrapped" ''
          export PATH="${
            pkgs.lib.makeBinPath (formatters {
              inherit pkgs;
            })
          }:$PATH"
          exec ${pkgs.treefmt}/bin/treefmt "$@"
        ''
      );

      packages = forEachSupportedSystem (
        { pkgs }: {
          parse-plays = pkgs.rustPlatform.buildRustPackage {
            pname = "parse-plays";
            version = "0.1.0";
            src = ./tools/parse-plays;
            cargoLock.lockFile = ./tools/parse-plays/Cargo.lock;
          };
        }
      );

      devShells = forEachSupportedSystem (
        { pkgs }: {
          default = pkgs.mkShell {
            packages =
              with pkgs;
              [
                gleam
                beamMinimal28Packages.erlang
                beamMinimal28Packages.rebar3
                treefmt
                just

                rustc
                cargo
                clippy
                cargo-edit
                rust-analyzer
              ]
              ++ (formatters { inherit pkgs; });
          };
        }
      );
    };
}
