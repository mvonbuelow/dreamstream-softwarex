{
  description = "Development shell with openprj and nvc";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    eepkgs = {
      url = "git+https://codeberg.org/gsi-ee/eepkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, eepkgs, ... }:
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
          eepkgs.legacyPackages.${system}.openprj
        ];
      };
    };
}
