#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
version="$(sed -n 's/^version=//p' "$ROOT/VERSION")"
build="$(sed -n 's/^build=//p' "$ROOT/VERSION")"

for tag in $(git -C "$ROOT" tag -l "v$version-*"); do
  n="${tag##*-}"
  if [[ "$n" =~ ^[0-9]+$ ]] && (( n > build )); then build="$n"; fi
done

echo $((build + 1))
