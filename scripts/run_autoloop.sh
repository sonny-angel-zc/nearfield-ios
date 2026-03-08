#!/usr/bin/env bash
set -euo pipefail

ROOT="/Users/sonny_angel/.openclaw/workspace/nearfield-ios-work"
cd "$ROOT"

# Temporary branch allowlist until workflow is merged to main.
export ALLOWED_RELEASE_BRANCH_REGEX='^(main|release/.+|sonny/setup-check)$'

# Keep build/upload enabled so TestFlight stays in the loop when auth is available.
export ENABLE_BUILD=1

"$ROOT/scripts/overnight_loop.sh"
