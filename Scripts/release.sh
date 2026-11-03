#!/bin/bash
set -euo pipefail

usage() {
  cat <<'TEXT'
Usage: Scripts/release.sh <ios|android|all> [--patch|--minor|--build] [--notes "text"] [--skip-tests] [--dry-run]

  --build   next build of the current version (default)
  --patch   1.3.1 -> 1.3.2, build 1
  --minor   1.3.1 -> 1.4.0, build 1
TEXT
  exit 1
}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Scripture Memory.xcodeproj/project.pbxproj"
CONFIG="${SCRIPTURE_MEMORY_CONFIG:-$HOME/.config/scripture-memory}"
WORK="$ROOT/build/release"
TARGET="${1:-}"
[[ "$TARGET" =~ ^(ios|android|all)$ ]] || usage
shift

BUMP=build
NOTES=""
SKIP_TESTS=0
DRY_RUN=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build|--patch|--minor) BUMP="${1#--}" ;;
    --notes) NOTES="$2"; shift ;;
    --skip-tests) SKIP_TESTS=1 ;;
    --dry-run) DRY_RUN=1 ;;
    *) usage ;;
  esac
  shift
done

read_version() { sed -n 's/^version=//p' "$ROOT/VERSION"; }
read_build() { sed -n 's/^build=//p' "$ROOT/VERSION"; }

bump() {
  local kind="$1" version build major minor patch
  version="$(read_version)"
  build="$(read_build)"
  IFS=. read -r major minor patch <<<"$version"
  case "$kind" in
    build) build="$("$ROOT/Scripts/next_build.sh")" ;;
    patch) version="$major.$minor.$((patch + 1))"; build=1 ;;
    minor) version="$major.$((minor + 1)).0"; build=1 ;;
  esac
  printf 'version=%s\nbuild=%s\n' "$version" "$build" >"$ROOT/VERSION"
}

apply_version() {
  sed -i '' -E \
    -e "s/MARKETING_VERSION = [0-9.]+;/MARKETING_VERSION = $(read_version);/g" \
    -e "s/CURRENT_PROJECT_VERSION = [0-9]+;/CURRENT_PROJECT_VERSION = $(read_build);/g" \
    "$PROJECT"
}

run_tests() {
  (cd "$ROOT" && swift test)
  "$ROOT/Scripts/check_android.sh"
  (cd "$ROOT/android" && ./gradlew :app:testDebugUnitTest)
}

upload_ios() {
  local log="$WORK/ios-upload.log"
  rm -rf "$WORK/ScriptureMemory.xcarchive" "$WORK/ipa"
  (cd "$ROOT" && xcrun xcodebuild archive \
    -project "Scripture Memory.xcodeproj" -scheme "Scripture Memory" \
    -configuration Release -destination "generic/platform=iOS" \
    -archivePath "$WORK/ScriptureMemory.xcarchive" -allowProvisioningUpdates -quiet)
  cat >"$WORK/ExportOptions.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>method</key><string>app-store-connect</string>
<key>destination</key><string>upload</string>
<key>teamID</key><string>767L2N7FG8</string>
<key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  # Homebrew rsync breaks the IPA step, so the export runs on the system PATH.
  PATH=/usr/bin:/bin:/usr/sbin:/sbin xcrun xcodebuild -exportArchive \
    -archivePath "$WORK/ScriptureMemory.xcarchive" -exportPath "$WORK/ipa" \
    -exportOptionsPlist "$WORK/ExportOptions.plist" -allowProvisioningUpdates >"$log" 2>&1
}

release_ios() {
  if upload_ios; then
    echo "iOS: uploaded $(read_version) ($(read_build)). It reaches TestFlight once App Store Connect finishes processing."
    return
  fi
  if grep -qE 'is closed for new build submissions|must contain a higher version' "$WORK/ios-upload.log"; then
    echo "iOS: $(read_version) is already live, so moving to the next patch version."
    bump patch
    apply_version
    upload_ios
    echo "iOS: uploaded $(read_version) ($(read_build))."
    return
  fi
  tail -20 "$WORK/ios-upload.log" >&2
  return 1
}

release_android() {
  if [[ -n "$NOTES" ]]; then
    local dir="$ROOT/android/app/src/main/play/release-notes/en-US"
    mkdir -p "$dir"
    printf '%s\n' "$NOTES" >"$dir/internal.txt"
  fi
  if [[ -f "$CONFIG/play-service-account.json" ]]; then
    (cd "$ROOT/android" && ./gradlew :app:publishReleaseBundle)
    echo "Android: uploaded $(read_version) ($(read_build)) to the Play internal track."
  else
    (cd "$ROOT/android" && ./gradlew :app:bundleRelease)
    echo "Android: built android/app/build/outputs/bundle/release/app-release.aab."
    echo "No $CONFIG/play-service-account.json yet, so nothing was uploaded. See RELEASING.md."
  fi
}

mkdir -p "$WORK"
if [[ "$SKIP_TESTS" == 0 ]]; then run_tests; fi
bump "$BUMP"
apply_version
if [[ "$DRY_RUN" == 1 ]]; then
  echo "Dry run: would release $TARGET as $(read_version) ($(read_build))."
  git -C "$ROOT" checkout -- VERSION "Scripture Memory.xcodeproj/project.pbxproj"
  exit 0
fi

if [[ "$TARGET" == ios || "$TARGET" == all ]]; then release_ios; fi
if [[ "$TARGET" == android || "$TARGET" == all ]]; then release_android; fi

TAG="v$(read_version)-$(read_build)"
git -C "$ROOT" add VERSION "Scripture Memory.xcodeproj/project.pbxproj"
if [[ -d "$ROOT/android/app/src/main/play" ]]; then git -C "$ROOT" add android/app/src/main/play; fi
git -C "$ROOT" commit -q -m "$(read_version) ($(read_build)): ${NOTES:-release $TARGET}"
git -C "$ROOT" tag "$TAG"
git -C "$ROOT" push -q origin HEAD "$TAG"
echo "Tagged $TAG."
