{
  description = "Development shell with openprj and nvc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    openprj = {
      url = "git+https://codeberg.org/gsi-ee/openprj.git?ref=main";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, openprj, ... }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };
    in
    {
      devShells.${system}.default = pkgs.mkShell {
        packages = [
          pkgs.nvc
          openprj.packages.${system}.openprj
        ];
      };
    };
}
