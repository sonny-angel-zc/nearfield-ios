# Nearfield Overnight Runbook

## Morning first command
```bash
cd /Users/sonny_angel/.openclaw/workspace/nearfield-ios-work && scripts/overnight_loop.sh
```

## One-time env setup (for CLI upload/status)
```bash
export ASC_KEY_ID="<key-id>"
export ASC_ISSUER_ID="<issuer-id>"
export ASC_PRIVATE_KEY_PATH="$HOME/.keys/AuthKey_<KEYID>.p8"
# optional fallback auth:
export APPLE_ID="<apple-id-email>"
export APP_PASSWORD="<app-specific-password>"
```

## Standard release candidate flow
```bash
cd /Users/sonny_angel/.openclaw/workspace/nearfield-ios-work
scripts/release_preflight.sh
scripts/archive_and_bump.sh
scripts/upload_testflight.sh
scripts/post_upload_check.sh
```

## Decision tree
1. **Preflight fails**
   - If dirty working tree: commit/stash first.
   - If branch not `main`/`release/*`: switch branch or set `ALLOWED_RELEASE_BRANCH_REGEX`.
2. **Archive fails**
   - Open `build` logs from Xcode.
   - Run same archive in Xcode once to surface signing/UI prompts.
3. **Upload fails with auth error**
   - Use fallback Xcode Organizer upload.
   - Re-run with API key env vars once fixed.
4. **Post-upload state stuck in PROCESSING**
   - Wait and re-run `scripts/post_upload_check.sh`.
   - If still blocked >45m, verify ASC warnings for missing compliance metadata.

## Queue-driven overnight loop
- Queue file: `docs/app-priority-queue.md`
- Each runnable task line format:
  - `- [ ] P1 | owner | slug | command`
- The loop executes one task per run, commits if changes exist, then attempts build+upload.

## Apple/Xcode auth unblock steps (if automation blocked)
1. Open Xcode and sign into the correct Apple Developer account.
2. In project Signing & Capabilities, refresh provisioning profiles.
3. Open Organizer once and perform one manual upload.
4. Accept any new license/compliance prompts in App Store Connect web.
5. Re-run CLI helpers.
