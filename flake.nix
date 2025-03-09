{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    zig.url = "github:mitchellh/zig-overlay";
  };
  outputs = {
    nixpkgs,
    zig,
    ...
  }: let
    forEachSupportedSystem = f:
      nixpkgs.lib.genAttrs ["x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin"] (system:
        f {
          pkgs = import nixpkgs {
            inherit system;

            overlays = [
              (final: prev: {
                zigpkgs = zig.packages.${prev.system};
              })
            ];
          };
        });
  in {
    devShells = forEachSupportedSystem ({pkgs}: {
      default = pkgs.mkShell {
        nativeBuildInputs = [pkgs.zigpkgs."0.14.0"];
      };
    });
  };
}
