{
  description = "An empty project that uses Zig.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    overlays = [
      # Other overlays
      (final: prev: {
        zigpkgs = inputs.zig.packages.${prev.system};
      })
    ];

    # Our supported systems are the same supported systems as the Zig binaries
    systems = builtins.attrNames inputs.zig.packages;
  in
    flake-utils.lib.eachSystem systems (
      system: let
        pkgs = import nixpkgs {inherit overlays system;};
      in {
        devShells.default = let
          newPost = pkgs.writeShellScriptBin "new-post" ''
            cat << EOF > content/posts/$(date '+%Y.%m.%d')-$1.md
            ---
            .title = "$1",
            .date = @date("$(date '+%Y-%m-%dT%H:%M:%S')"),
            .author = "Karitham",
            .draft = true,
            .layout = "post.html",
            .tags = [],
            ---
            EOF
          '';
        in
          pkgs.mkShell
          {
            nativeBuildInputs = with pkgs; [
              zigpkgs.master
              newPost
            ];
          };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      }
    );
}
