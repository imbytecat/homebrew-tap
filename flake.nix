{
  description = "imbytecat's homebrew tap dev shell";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      nixpkgs,
      flake-utils,
      ...
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs { inherit system; };
        ruby = pkgs.ruby_3_3.withPackages (ps: [ ps.rubocop ]);
      in
      {
        devShells.default = pkgs.mkShellNoCC {
          packages = [
            ruby
            pkgs.just
            pkgs.curl
          ];
        };

        formatter = pkgs.nixfmt-rfc-style;
      }
    );
}
