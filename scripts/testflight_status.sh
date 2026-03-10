#!/usr/bin/env bash
set -euo pipefail

# Required env:
# ASC_ISSUER_ID
# ASC_KEY_ID
# ASC_PRIVATE_KEY_PATH
# Optional:
# ASC_BUNDLE_ID (default: com.nearfield.app)
# TF_STATE_FILE (default: ./.testflight-status.json)

BUNDLE_ID="${ASC_BUNDLE_ID:-com.nearfield.app}"
STATE_FILE="${TF_STATE_FILE:-$(pwd)/.testflight-status.json}"

if [[ -z "${ASC_ISSUER_ID:-}" || -z "${ASC_KEY_ID:-}" || -z "${ASC_PRIVATE_KEY_PATH:-}" ]]; then
  echo "ERROR: missing ASC_ISSUER_ID / ASC_KEY_ID / ASC_PRIVATE_KEY_PATH" >&2
  exit 2
fi

if [[ ! -f "$ASC_PRIVATE_KEY_PATH" ]]; then
  echo "ERROR: ASC_PRIVATE_KEY_PATH not found: $ASC_PRIVATE_KEY_PATH" >&2
  exit 2
fi

b64url() {
  openssl base64 -A | tr '+/' '-_' | tr -d '='
}

now=$(date +%s)
exp=$((now + 1200))
header='{"alg":"ES256","kid":"'"$ASC_KEY_ID"'","typ":"JWT"}'
payload='{"iss":"'"$ASC_ISSUER_ID"'","iat":'"$now"',"exp":'"$exp"',"aud":"appstoreconnect-v1"}'

h64=$(printf '%s' "$header" | b64url)
p64=$(printf '%s' "$payload" | b64url)
unsigned="$h64.$p64"
sig=$(printf '%s' "$unsigned" | openssl dgst -binary -sha256 -sign "$ASC_PRIVATE_KEY_PATH" | b64url)
JWT="$unsigned.$sig"

api_get() {
  local url="$1"
  curl -g -fsSL "$url" \
    -H "Authorization: Bearer $JWT" \
    -H 'Content-Type: application/json'
}

app_json=$(api_get "https://api.appstoreconnect.apple.com/v1/apps?filter[bundleId]=$BUNDLE_ID")
app_id=$(python3 - <<'PY' "$app_json"
import json,sys
j=json.loads(sys.argv[1])
arr=j.get('data') or []
print(arr[0]['id'] if arr else '')
PY
)

if [[ -z "$app_id" ]]; then
  echo "ERROR: no ASC app found for bundle id $BUNDLE_ID" >&2
  exit 3
fi

builds_json=$(api_get "https://api.appstoreconnect.apple.com/v1/builds?filter[app]=$app_id&limit=5&sort=-uploadedDate")
summary=$(python3 - <<'PY' "$builds_json" "$app_id" "$BUNDLE_ID"
import json,sys
j=json.loads(sys.argv[1])
app_id=sys.argv[2]
bundle=sys.argv[3]
arr=j.get('data') or []
if not arr:
    out={"ok":True,"appId":app_id,"bundleId":bundle,"hasBuild":False}
    print(json.dumps(out))
    raise SystemExit(0)
b=arr[0]
a=b.get('attributes') or {}
out={
  "ok": True,
  "appId": app_id,
  "bundleId": bundle,
  "hasBuild": True,
  "id": b.get('id'),
  "version": a.get('version'),
  "buildNumber": a.get('buildNumber'),
  "processingState": a.get('processingState'),
  "uploadedDate": a.get('uploadedDate'),
  "expired": a.get('expired')
}
print(json.dumps(out))
PY
)

printf '%s\n' "$summary"

mkdir -p "$(dirname "$STATE_FILE")"
printf '%s\n' "$summary" > "$STATE_FILE"
