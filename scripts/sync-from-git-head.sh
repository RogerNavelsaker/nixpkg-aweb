#!/usr/bin/env bash
# Pin flake.nix to upstream awebai/aweb HEAD (rev, source hash, unstable-<date> version).
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
repo=awebai/aweb
new=$(git ls-remote "https://github.com/$repo" HEAD | awk '{print $1}')
[ -n "$new" ] || { echo "no upstream HEAD" >&2; exit 1; }
old=$(grep -oE 'rev = "[0-9a-f]{40}"' flake.nix | head -n1 | sed -E 's/.*"([^"]+)"/\1/')
[ "$new" != "$old" ] || { echo "up to date: $old"; exit 0; }
hash=$(nix flake prefetch "github:$repo/$new" --json | jq -r .hash)
date=$(gh api "repos/$repo/commits/$new" -q .commit.committer.date | cut -c1-10)
sed -i -E \
  -e "s/$old/$new/g" \
  -e "s|(hash = )\"sha256-[^\"]+\"|\1\"$hash\"|" \
  -e "s/unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}/unstable-$date/g" flake.nix
sed -i -E "s/unstable-[0-9]{4}-[0-9]{2}-[0-9]{2}/unstable-$date/g" .github/workflows/publish.yml
echo "bumped $old -> $new"
# Refresh Go vendorHash: build with a fake hash and read the real one from the mismatch.
fake="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
oldvh=$(grep -oE 'vendorHash = "sha256-[^"]+"' flake.nix | head -n1 | sed -E 's/.*"([^"]+)"/\1/')
sed -i "s|$oldvh|$fake|" flake.nix
newvh=$(nix build .#aw --no-link --accept-flake-config 2>&1 | awk '/got:/{print $2; exit}' || true)
[ -n "$newvh" ] && sed -i "s|$fake|$newvh|" flake.nix || { sed -i "s|$fake|$oldvh|" flake.nix; echo "vendorHash unchanged"; }
