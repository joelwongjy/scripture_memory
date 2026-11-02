#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../android"
if grep -rnE 'androidx\.compose\.material|com\.google\.android\.material' app/src app/build.gradle.kts gradle/libs.versions.toml; then
  echo "Material is not used in this app. See android/PORTING.md." >&2
  exit 1
fi
