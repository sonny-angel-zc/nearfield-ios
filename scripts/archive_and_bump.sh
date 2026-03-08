#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="${SCHEME:-Nearfield}"
WORKSPACE="${WORKSPACE:-Nearfield.xcodeproj/project.xcworkspace}"
CONFIGURATION="${CONFIGURATION:-Release}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT/build/${SCHEME}.xcarchive}"
AUTO_BUMP="${AUTO_BUMP_BUILD_NUMBER:-1}"

get_build_number() {
  grep -m1 'CURRENT_PROJECT_VERSION = ' Nearfield.xcodeproj/project.pbxproj | sed -E 's/.*CURRENT_PROJECT_VERSION = ([0-9]+);/\1/'
}

set_build_number() {
  local next="$1"
  perl -0pi -e "s/CURRENT_PROJECT_VERSION = \d+;/CURRENT_PROJECT_VERSION = ${next};/g" Nearfield.xcodeproj/project.pbxproj
}

current="$(get_build_number)"
if [[ ! "$current" =~ ^[0-9]+$ ]]; then
  echo "ERROR: Could not parse CURRENT_PROJECT_VERSION" >&2
  exit 2
fi

if [[ "$AUTO_BUMP" == "1" ]]; then
  next=$((current + 1))
  set_build_number "$next"
  echo "Bumped build number: $current -> $next"
else
  next="$current"
  echo "Build number unchanged: $current"
fi

mkdir -p "$(dirname "$ARCHIVE_PATH")"

xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -archivePath "$ARCHIVE_PATH" \
  archive

echo "Archive complete: $ARCHIVE_PATH"
echo "Build number: $next"
