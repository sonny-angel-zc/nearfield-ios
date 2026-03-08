#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

IPA_PATH="${IPA_PATH:-$ROOT/build/export/Nearfield.ipa}"
APPLE_ID="${APPLE_ID:-}"
APP_PASSWORD="${APP_PASSWORD:-}"
ASC_API_KEY="${ASC_API_KEY_PATH:-${ASC_PRIVATE_KEY_PATH:-}}"
ASC_KEY_ID="${ASC_KEY_ID:-}"
ASC_ISSUER_ID="${ASC_ISSUER_ID:-}"

if [[ ! -f "$IPA_PATH" ]]; then
  echo "ERROR: IPA not found at $IPA_PATH" >&2
  exit 2
fi

upload_with_api_key() {
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"
}

upload_with_apple_id() {
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --username "$APPLE_ID" \
    --password "$APP_PASSWORD"
}

if [[ -n "$ASC_KEY_ID" && -n "$ASC_ISSUER_ID" ]]; then
  echo "Uploading with App Store Connect API key..."
  upload_with_api_key
  echo "Upload submitted via API key"
  exit 0
fi

if [[ -n "$APPLE_ID" && -n "$APP_PASSWORD" ]]; then
  echo "Uploading with Apple ID + app-specific password..."
  upload_with_apple_id
  echo "Upload submitted via Apple ID"
  exit 0
fi

cat <<'EOF'
No non-interactive upload auth detected.

Fallback (Xcode UI):
1) Open Xcode Organizer.
2) Select the archive.
3) Distribute App -> App Store Connect -> Upload.
4) Keep "Upload your app's symbols" enabled.
5) Complete upload wizard.

To enable CLI upload next run, set one of:
- ASC_KEY_ID + ASC_ISSUER_ID (+ key configured in App Store Connect account)
- APPLE_ID + APP_PASSWORD (app-specific password)
EOF
exit 3
