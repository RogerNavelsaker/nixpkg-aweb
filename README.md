# Aweb Nix packages and OCI images

Pinned upstream source: [awebai/aweb](https://github.com/awebai/aweb), commit `e0d81e5a02dd663fc0f5a5054828dccab86c47b3`.

## Build

```sh
nix build .#aw
nix build .#aweb-a2a-gw
nix build .#aweb-image
nix build .#awid-image
```

Load OCI archives with Podman:

```sh
podman load -i result
podman load -i result-1
```

The image outputs are separate: `aweb:unstable-2026-11-05` (TCP 8000) and `awid:unstable-2026-11-05` (TCP 8010). Both run as UID/GID `10001:10001`, include only the locked Python runtime and required certificates/timezone data, and have no shell or package manager in PATH. They expect external PostgreSQL and Redis services; configure database URLs, the shared `AWID_SERVICE_TOKEN`, registry URLs, and public origin through environment variables as in upstream `server/docker-compose.yml`.

## Development tools

`devenv shell` provides Go, uv, Git, Podman, jq, and curl. The Go tests are disabled in Nix builds because upstream tests require uv and network DNS behavior unavailable in the Nix build sandbox.

Nix flake checks build both OCI image archives. Local Podman smoke checks used `podman load` and `podman run --rm IMAGE --help` for both service entrypoints.
