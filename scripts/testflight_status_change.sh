#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
STATE_FILE="${TF_STATE_FILE:-$ROOT/.testflight-status.json}"
TMP_FILE="$ROOT/.testflight-status.new.json"

prev=""
if [[ -f "$STATE_FILE" ]]; then
  prev=$(cat "$STATE_FILE" || true)
fi

new="$($ROOT/scripts/testflight_status.sh)"
printf '%s\n' "$new" > "$TMP_FILE"

if [[ "$new" != "$prev" ]]; then
  echo "changed"
  cat "$TMP_FILE"
else
  echo "unchanged"
fi

mv "$TMP_FILE" "$STATE_FILE"
