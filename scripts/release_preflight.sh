#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[0;33m'
NC='\033[0m'

fail() { echo -e "${RED}✗ $*${NC}"; exit 1; }
pass() { echo -e "${GRN}✓ $*${NC}"; }
warn() { echo -e "${YLW}! $*${NC}"; }

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
ALLOWED_REGEX="${ALLOWED_RELEASE_BRANCH_REGEX:-^(main|release/.+)$}"
REQUIRE_RELEASE_BRANCH="${REQUIRE_RELEASE_BRANCH:-0}"

if [[ ! "$BRANCH" =~ $ALLOWED_REGEX ]]; then
  if [[ "$REQUIRE_RELEASE_BRANCH" == "1" ]]; then
    fail "Release must be built from main/release branch. Current: $BRANCH"
  fi
  warn "Current branch $BRANCH is outside $ALLOWED_REGEX; continuing because REQUIRE_RELEASE_BRANCH=0"
else
  pass "Branch check ($BRANCH)"
fi

DIRTY_NON_EPHEMERAL="$(git status --porcelain | grep -vE '^(\?\?| M|M ) (docs/nightly-status.md|\.testflight-status\.json)$' || true)"
if [[ -n "$DIRTY_NON_EPHEMERAL" ]]; then
  fail "Working tree is dirty. Commit/stash changes before release build."
fi
pass "Working tree is clean (ignoring ephemeral status files)"

if git remote get-url origin >/dev/null 2>&1; then
  git fetch origin -q || true
  if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
    LOCAL_SHA="$(git rev-parse HEAD)"
    REMOTE_SHA="$(git rev-parse "origin/$BRANCH")"
    if [[ "$LOCAL_SHA" != "$REMOTE_SHA" ]]; then
      warn "HEAD differs from origin/$BRANCH (local=$LOCAL_SHA remote=$REMOTE_SHA)"
    else
      pass "HEAD matches origin/$BRANCH"
    fi
  fi
fi

INFO_PLIST="Nearfield/Nearfield/Info.plist"
[[ -f "$INFO_PLIST" ]] || fail "Missing $INFO_PLIST"

grep -q "<key>CFBundleIconName</key>" "$INFO_PLIST" || fail "CFBundleIconName missing in Info.plist"
pass "Info.plist has CFBundleIconName"

ICON_SET="Nearfield/Nearfield/Assets.xcassets/AppIcon.appiconset/Contents.json"
[[ -f "$ICON_SET" ]] || fail "Missing AppIcon asset set Contents.json"
pass "AppIcon asset set exists"

BUILD_NUM_LINE="$(grep -m1 'CURRENT_PROJECT_VERSION' Nearfield.xcodeproj/project.pbxproj || true)"
BUILD_NUM="$(printf '%s' "$BUILD_NUM_LINE" | sed -E 's/.*CURRENT_PROJECT_VERSION[^0-9]*([0-9]+).*/\1/')"
if [[ "$BUILD_NUM" =~ ^[0-9]+$ ]]; then
  pass "Build number parsed: $BUILD_NUM"
else
  warn "Could not parse CURRENT_PROJECT_VERSION (this project may rely on MARKETING_VERSION-only workflow)"
  BUILD_NUM=""
fi

command -v xcodebuild >/dev/null 2>&1 || fail "xcodebuild is not installed / not in PATH"
pass "xcodebuild available"

if [[ -f "$ROOT/docs/app-priority-queue.md" ]]; then
  grep -Eq '^- \[ \] P[0-2] \|' "$ROOT/docs/app-priority-queue.md" || warn "No queued tasks found in docs/app-priority-queue.md"
  pass "Task queue file present"
fi

# Optional: compare against latest uploaded build in ASC if credentials are available
if [[ -n "${ASC_ISSUER_ID:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_PRIVATE_KEY_PATH:-}" ]]; then
  if OUT="$("$ROOT/scripts/testflight_status.sh" 2>/dev/null || true)"; then
    LATEST="$(python3 - <<'PY' "$OUT"
import json,sys
try:
    j=json.loads(sys.argv[1])
    print(j.get('buildNumber') or '')
except Exception:
    print('')
PY
)"
    if [[ "$LATEST" =~ ^[0-9]+$ && "$BUILD_NUM" =~ ^[0-9]+$ ]]; then
      if (( BUILD_NUM <= LATEST )); then
        fail "Build number $BUILD_NUM is not greater than latest TestFlight build $LATEST"
      fi
      pass "Build number $BUILD_NUM is greater than latest TestFlight build $LATEST"
    elif [[ "$LATEST" =~ ^[0-9]+$ ]]; then
      warn "Latest TestFlight build is $LATEST but local build number could not be parsed"
    else
      warn "Could not determine latest TestFlight build number"
    fi
  fi
else
  warn "ASC credentials not set; skipping TestFlight build-number comparison"
fi

pass "Release preflight passed"
