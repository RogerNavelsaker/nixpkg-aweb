# Aweb CLI tools and OCI images

Nix packages for Aweb, pinned to upstream commit `e0d81e5a02dd663fc0f5a5054828dccab86c47b3` (2026-11-05).

## CLI builds

```sh
nix build .#aw
nix build .#aweb-a2a-gw
```

The upstream Go test suite is disabled in these derivations: tests require `uv` and network DNS behavior unavailable in the Nix build sandbox. Flake evaluation and both binary builds pass. Runtime OCI images remain unimplemented.

Source and runtime reference: [Aweb self-hosting guide](https://github.com/awebai/aweb/blob/main/docs/self-hosting-guide.md).
