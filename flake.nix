{
  description = "Aweb CLI tools from pinned upstream source";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { nixpkgs, ... }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
      source = pkgs.fetchFromGitHub {
        owner = "awebai";
        repo = "aweb";
        rev = "e0d81e5a02dd663fc0f5a5054828dccab86c47b3";
        hash = "sha256-8m7aAUszPREmqaPBj7IlYDNcJuvLsN46jj7l68trEUg=";
      };
      buildCli = { pname, subPackage }:
        pkgs.buildGoModule {
          inherit pname;
          version = "unstable-2026-11-05";
          src = source;
          sourceRoot = "source/cli/go";
          vendorHash = "sha256-U1rzmQ+oqKY3alYD1gsh4ZWJtFhKDJXd5wkxC7EPIs8=";
          subPackages = [ subPackage ];
          doCheck = false;
          ldflags = [ "-s" "-w" ];
        };
      aw = buildCli { pname = "aw"; subPackage = "cmd/aw"; };
      aweb-a2a-gw = buildCli { pname = "aweb-a2a-gw"; subPackage = "cmd/aweb-a2a-gw"; };
    in {
      packages.${system} = { inherit aw aweb-a2a-gw; default = aw; };
    };
}
