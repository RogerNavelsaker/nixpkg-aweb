{
  description = "Aweb CLI tools and separate OCI images built with Nix";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    pyproject-nix = { url = "github:pyproject-nix/pyproject.nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    uv2nix = { url = "github:pyproject-nix/uv2nix"; inputs.pyproject-nix.follows = "pyproject-nix"; inputs.nixpkgs.follows = "nixpkgs"; };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.pyproject-nix.follows = "pyproject-nix";
      inputs.uv2nix.follows = "uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = { nixpkgs, pyproject-nix, uv2nix, pyproject-build-systems, ... }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" ];
      source = nixpkgs.legacyPackages.x86_64-linux.fetchFromGitHub {
        owner = "awebai"; repo = "aweb";
        rev = "e0d81e5a02dd663fc0f5a5054828dccab86c47b3";
        hash = "sha256-8m7aAUszPREmqaPBj7IlYDNcJuvLsN46jj7l68trEUg=";
      };
      buildCli = pkgs: { pname, subPackage }: pkgs.buildGoModule {
        inherit pname; version = "unstable-2026-11-05"; src = source;
        sourceRoot = "source/cli/go";
        vendorHash = "sha256-U1rzmQ+oqKY3alYD1gsh4ZWJtFhKDJXd5wkxC7EPIs8=";
        subPackages = [ subPackage ]; doCheck = false; ldflags = [ "-s" "-w" ];
      };
      mkPythonSet = pkgs: root:
        let
          workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = "${source}/${root}"; };
          overlay = workspace.mkPyprojectOverlay { sourcePreference = "wheel"; };
        in {
          inherit workspace;
          set = (pkgs.callPackage pyproject-nix.build.packages { python = pkgs.python312; }).overrideScope
            (lib.composeManyExtensions [ pyproject-build-systems.overlays.wheel overlay ]);
        };
      forSystem = system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          aw = (buildCli pkgs) { pname = "aw"; subPackage = "cmd/aw"; };
          aweb-a2a-gw = (buildCli pkgs) { pname = "aweb-a2a-gw"; subPackage = "cmd/aweb-a2a-gw"; };
          mkService = { name, root, program, port, revision }:
            let
              python = mkPythonSet pkgs root;
              environment = python.set.mkVirtualEnv "${name}-environment" python.workspace.deps.default;
              image = pkgs.dockerTools.buildLayeredImage {
                inherit name; tag = "unstable-2026-11-05"; maxLayers = 10;
                contents = [ environment pkgs.python312 pkgs.dockerTools.fakeNss pkgs.cacert pkgs.tzdata ];
                fakeRootCommands = ''
                  mkdir -p ./tmp ./app
                  chmod 1777 ./tmp
                '';
                config = {
                  User = "10001:10001"; WorkingDir = "/app";
                  Entrypoint = [ "${environment}/bin/${program}" ];
                  Cmd = if name == "aweb" then [ "serve" "--host" "0.0.0.0" "--port" "8000" ] else [ "--host" "0.0.0.0" "--port" "8010" ];
                  Env = [
                    "PATH=${environment}/bin:${pkgs.python312}/bin" "HOME=/tmp" "TMPDIR=/tmp"
                    "PYTHONUNBUFFERED=1" "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
                    "TZDIR=${pkgs.tzdata}/share/zoneinfo"
                  ];
                  ExposedPorts = { "${toString port}/tcp" = { }; };
                  Labels = {
                    "org.opencontainers.image.title" = name;
                    "org.opencontainers.image.source" = "https://github.com/awebai/aweb";
                    "org.opencontainers.image.revision" = revision;
                    "org.opencontainers.image.description" = "Nix-built Aweb service image; non-root, minimal runtime";
                  };
                };
              };
            in { inherit environment image; };
          awebService = mkService { name = "aweb"; root = "server"; program = "aweb"; port = 8000; revision = "e0d81e5a02dd663fc0f5a5054828dccab86c47b3"; };
          awidService = mkService { name = "awid"; root = "awid"; program = "awid"; port = 8010; revision = "e0d81e5a02dd663fc0f5a5054828dccab86c47b3"; };
        in {
          packages = { inherit aw aweb-a2a-gw; aweb-image = awebService.image; awid-image = awidService.image; default = aw; };
          checks = { aweb-image = awebService.image; awid-image = awidService.image; };
        };
    in {
      packages = lib.genAttrs systems (system: (forSystem system).packages);
      checks = lib.genAttrs systems (system: (forSystem system).checks);
    };
}
