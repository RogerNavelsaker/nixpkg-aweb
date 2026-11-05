{ pkgs, ... }:
{
  packages = with pkgs; [
    go
    uv
    git
    podman
    jq
    curl
  ];
}
