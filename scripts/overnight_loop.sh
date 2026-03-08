#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

QUEUE_FILE="${QUEUE_FILE:-$ROOT/docs/app-priority-queue.md}"
STATUS_FILE="${STATUS_FILE:-$ROOT/docs/nightly-status.md}"
BRANCH="${BRANCH:-$(git rev-parse --abbrev-ref HEAD)}"
ENABLE_BUILD="${ENABLE_BUILD:-1}"

log() {
  local msg="$1"
  printf -- "- [%s] %s\n" "$(date '+%Y-%m-%d %H:%M:%S %Z')" "$msg" >> "$STATUS_FILE"
}

pick_task() {
  python3 - <<'PY' "$QUEUE_FILE"
import re,sys
p=sys.argv[1]
for line in open(p, encoding='utf-8'):
    m=re.match(r"- \[ \] (P[0-2]) \| ([^|]+) \| ([^|]+) \| (.+)$", line.strip())
    if m:
        print("\t".join([m.group(1), m.group(2).strip(), m.group(3).strip(), m.group(4).strip(), line.rstrip("\n")]))
        raise SystemExit(0)
raise SystemExit(1)
PY
}

mark_done() {
  local raw="$1"
  python3 - <<'PY' "$QUEUE_FILE" "$raw"
import sys
path,raw=sys.argv[1],sys.argv[2]
text=open(path, encoding='utf-8').read()
text=text.replace(raw, raw.replace('- [ ]','- [x]',1),1)
open(path,'w',encoding='utf-8').write(text)
PY
}

mkdir -p "$(dirname "$STATUS_FILE")"
[[ -f "$STATUS_FILE" ]] || echo "# Nearfield Nightly Status" > "$STATUS_FILE"

if ! "$ROOT/scripts/release_preflight.sh" >/tmp/nearfield-preflight.log 2>&1; then
  log "Overnight loop start (branch=$BRANCH)"
  log "Preflight failed. See /tmp/nearfield-preflight.log"
  exit 1
fi

log "Overnight loop start (branch=$BRANCH)"
log "Preflight passed"

if ! task_row="$(pick_task)"; then
  log "No pending task in queue; exiting cleanly"
  exit 0
fi

IFS=$'\t' read -r priority owner slug cmd raw_line <<< "$task_row"
log "Picked task $slug ($priority) owner=$owner"

set +e
bash -lc "$cmd" >/tmp/nearfield-task.log 2>&1
task_rc=$?
set -e

if [[ $task_rc -ne 0 ]]; then
  log "Task $slug failed (rc=$task_rc). See /tmp/nearfield-task.log"
  exit 2
fi

mark_done "$raw_line"
log "Marked queue task done: $slug"

if [[ -n "$(git status --porcelain)" ]]; then
  git add -A
  git commit -m "overnight: $slug"
  log "Committed task changes: overnight: $slug"
else
  log "Task $slug made no repo changes"
fi

if [[ "$ENABLE_BUILD" == "1" ]]; then
  set +e
  "$ROOT/scripts/archive_and_bump.sh" >/tmp/nearfield-archive.log 2>&1
  arc_rc=$?
  set -e

  if [[ $arc_rc -ne 0 ]]; then
    log "Archive failed (rc=$arc_rc). See /tmp/nearfield-archive.log"
    exit 3
  fi

  log "Archive succeeded"

  set +e
  "$ROOT/scripts/upload_testflight.sh" >/tmp/nearfield-upload.log 2>&1
  upload_rc=$?
  set -e

  if [[ $upload_rc -eq 0 ]]; then
    log "Upload submitted"
    "$ROOT/scripts/post_upload_check.sh" >/tmp/nearfield-post-upload.log 2>&1 || true
    log "Post-upload check executed"
  else
    log "Upload not completed via CLI (rc=$upload_rc). Follow fallback in scripts/upload_testflight.sh"
  fi
fi

log "Overnight loop completed"
