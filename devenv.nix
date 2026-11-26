{ pkgs, ... }:
{
  imports = [ /workspace/common/main/devenv.nix ];

  packages = with pkgs; [
    go
    uv
    git
    podman
    jq
    curl
  ];
}
