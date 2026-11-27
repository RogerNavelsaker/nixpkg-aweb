{
  description = "Aweb CLI tools and separate OCI images built with Nix";
  nixConfig = {
    extra-substituters = [
      "https://cache.nixos.org"
      "https://nix-community.cachix.org"
      "https://rogernavelsaker.cachix.org"
      "https://nacosolutions.cachix.org"
    ];
    extra-trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "rogernavelsaker.cachix.org-1:n1DtzMNhA9Rz4Kg3xlXOi/KceULu8VrMbs9WXyMFQNQ="
      "nacosolutions.cachix.org-1:JzCiW2CLcuLXtwOVAg3SlSK/kpqWbfSFEVenyKVUlug="
    ];
  };

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
        rev = "5c2ee7bad33ba0c103b661814e5d83ab50887bb7";
        hash = "sha256-wRFRSxJzm3neEKKbQF5ZT6PVC1fFg0+ov1mZB1ZBCis=";
      };
      buildCli = pkgs: { pname, subPackage }: pkgs.buildGoModule {
        inherit pname; version = "unstable-2026-11-27"; src = source;
        sourceRoot = "source/cli/go";
        vendorHash = "sha256-VA2GEjPDUaQySEW1V3O2GeI7tX58llVepDMZz7D7rmc=";
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
                inherit name; tag = "unstable-2026-11-27"; maxLayers = 10;
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
          awebService = mkService { name = "aweb"; root = "server"; program = "aweb"; port = 8000; revision = "5c2ee7bad33ba0c103b661814e5d83ab50887bb7"; };
          awidService = mkService { name = "awid"; root = "awid"; program = "awid"; port = 8010; revision = "5c2ee7bad33ba0c103b661814e5d83ab50887bb7"; };
        in {
          packages = { inherit aw aweb-a2a-gw; aweb-image = awebService.image; awid-image = awidService.image; default = aw; };
          checks = { aweb-image = awebService.image; awid-image = awidService.image; };
        };
    in {
      packages = lib.genAttrs systems (system: (forSystem system).packages);
      checks = lib.genAttrs systems (system: (forSystem system).checks);
    };
}
