#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

MAX_POLLS="${MAX_POLLS:-12}"
SLEEP_SECONDS="${SLEEP_SECONDS:-120}"

if [[ -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_PRIVATE_KEY_PATH:-}" ]]; then
  echo "WARN: ASC credentials missing; cannot poll processing state automatically."
  echo "Use Xcode Organizer / App Store Connect web to verify processing and tester assignment."
fi

poll_once() {
  if out="$ROOT/scripts/testflight_status.sh" 2>/dev/null; then
    echo "$out"
    return 0
  fi
  return 1
}

latest=""
for ((i=1; i<=MAX_POLLS; i++)); do
  if latest="$(poll_once)"; then
    state="$(python3 - <<'PY' "$latest"
import json,sys
try:
  j=json.loads(sys.argv[1])
  print(j.get('processingState') or '')
except Exception:
  print('')
PY
)"
    echo "Poll $i/$MAX_POLLS processingState=${state:-unknown}"
    if [[ "$state" == "VALID" || "$state" == "PROCESSING_COMPLETE" ]]; then
      break
    fi
  fi

  if (( i < MAX_POLLS )); then
    sleep "$SLEEP_SECONDS"
  fi
done

cat <<'EOF'

Post-upload checklist:
[ ] Confirm build is visible in App Store Connect -> TestFlight
[ ] Confirm processing finished (no warnings requiring action)
[ ] Assign build to Internal tester group
[ ] Assign build to External tester group (if review already approved)
[ ] Add release notes focused on tonight's changes
[ ] Smoke test install on at least one physical iPhone
EOF
