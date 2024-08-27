{
  description = "An empty project that uses Zig.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";
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
        superHTML = pkgs.stdenv.mkDerivation rec {
          name = "superhtml";
          version = "0.4.3";
          triplet = "x86_64-linux-musl";
          src = pkgs.fetchurl {
            url = "https://github.com/kristoff-it/superhtml/releases/download/v${version}/${triplet}.tar.gz";
            sha256 = "sha256-PQg0NEM4nkLxQzAoZfNrCJ+RCTYqJfPRlWWVxAOFlpg=";
          };
          phases = ["unpackPhase" "installPhase"];
          unpackPhase = "tar -xzf $src";
          installPhase = ''
            mkdir -p $out/bin
            cp ${triplet}/superhtml $out/bin/
            chmod +x $out/bin/superhtml
          '';
        };
      in {
        devShells.default = let
          newPost = pkgs.writeShellScriptBin "new-post" ''
            cat << EOF > content/posts/$1.md
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
              superHTML
            ];
          };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      }
    );
}
