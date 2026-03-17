#!/usr/bin/env bash
set -euo pipefail

# Required env:
# ASC_KEY_ID
# ASC_ISSUER_ID
#
# Optional:
# DELIVERY_ID
# DELIVERY_ID_FILE (default: ./.testflight-delivery-id)
# TF_STATE_FILE (default: ./.testflight-status.json)

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

DELIVERY_ID_FILE="${DELIVERY_ID_FILE:-$ROOT/.testflight-delivery-id}"
STATE_FILE="${TF_STATE_FILE:-$ROOT/.testflight-status.json}"
DELIVERY_ID="${DELIVERY_ID:-}"

if [[ -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_ID:-}" ]]; then
  echo "ERROR: missing ASC_ISSUER_ID / ASC_KEY_ID" >&2
  exit 2
fi

if [[ -z "$DELIVERY_ID" && -f "$DELIVERY_ID_FILE" ]]; then
  DELIVERY_ID="$(tr -d '\n' < "$DELIVERY_ID_FILE")"
fi

if [[ -z "$DELIVERY_ID" ]]; then
  cat <<EOF >&2
ERROR: no delivery UUID available.
Provide DELIVERY_ID or run scripts/upload_testflight.sh first so it can persist one to:
  $DELIVERY_ID_FILE
EOF
  exit 2
fi

raw="$(xcrun altool --build-status \
  --delivery-id "$DELIVERY_ID" \
  --apiKey "$ASC_KEY_ID" \
  --apiIssuer "$ASC_ISSUER_ID" \
  --output-format json)"

summary="$(python3 - <<'PY' "$raw" "$DELIVERY_ID"
import json,sys

payload=json.loads(sys.argv[1])
delivery_id=sys.argv[2]

state=payload.get("build-status") or payload.get("buildStatus") or ""
out={
  "ok": True,
  "deliveryId": payload.get("delivery-uuid") or payload.get("deliveryId") or delivery_id,
  "processingState": state,
  "buildStatus": state,
  "raw": payload,
}
print(json.dumps(out))
PY
)"

printf '%s\n' "$summary"
mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$summary" > "$STATE_FILE"
