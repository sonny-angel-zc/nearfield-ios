#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-Nearfield}"
PROJECT="${PROJECT:-Nearfield.xcodeproj}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/${SCHEME}.xcarchive}"
AUTO_BUMP="${AUTO_BUMP_BUILD_NUMBER:-1}"

get_build_number() {
  grep -m1 'CURRENT_PROJECT_VERSION' Nearfield.xcodeproj/project.pbxproj | sed -E 's/.*CURRENT_PROJECT_VERSION[^0-9]*([0-9]+).*/\1/' || true
}

set_build_number() {
  local next="$1"
  if grep -q 'CURRENT_PROJECT_VERSION' Nearfield.xcodeproj/project.pbxproj; then
    perl -0pi -e "s/CURRENT_PROJECT_VERSION\s*=\s*\d+;/CURRENT_PROJECT_VERSION = ${next};/g" Nearfield.xcodeproj/project.pbxproj
  fi
}

current="$(get_build_number)"
if [[ "$AUTO_BUMP" == "1" && "$current" =~ ^[0-9]+$ ]]; then
  next=$((current + 1))
  set_build_number "$next"
  echo "Bumped build number: $current -> $next"
elif [[ "$current" =~ ^[0-9]+$ ]]; then
  next="$current"
  echo "Build number unchanged: $current"
else
  next="unknown"
  echo "No CURRENT_PROJECT_VERSION found; continuing without auto-bump"
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE_PATH" \
  archive \
  -allowProvisioningUpdates

echo "Archive complete: $ARCHIVE_PATH"
echo "Build number: $next"
