# Nearfield Overnight Workflow (Polish + TestFlight)

## Goal
Ship frequent, safe TestFlight builds for **Nearfield Sonic** (`com.nearfield.app`) while implementing Grainfield mode in small, reviewable slices.

## Work Queue Source of Truth
- Primary queue file: `docs/app-priority-queue.md`
- Nightly log: `docs/nightly-status.md`
- Grainfield breakdown: `docs/grainfield-mode-plan.md`

## Suggested Linear Mapping (manual)
If/when Linear access is available, mirror queue rows to Linear using this convention:

- **Team**: Nearfield
- **Project**: Nearfield iOS
- **Labels**: `ios`, `testflight`, `grainfield`, `overnight`
- **Priority mapping**:
  - `P0` = must ship next build
  - `P1` = should ship this week
  - `P2` = polish/backlog
- **State mapping**:
  - `todo` -> Backlog
  - `doing` -> In Progress
  - `blocked` -> Blocked
  - `done` -> Done

### Issue title template
`[Nearfield iOS] <short task title>`

### Description template
- Why this matters
- Scope (explicit in/out)
- Acceptance criteria
- Test notes (device + simulator)
- Rollback plan

## Overnight cycle
1. `scripts/overnight_loop.sh` selects next `todo` task from queue.
2. Runs task command (small slice), validates, commits changes.
3. If build conditions are good, attempts archive + upload helpers.
4. Captures status + blockers in `docs/nightly-status.md`.

## Safety defaults
- Never force-push from automation.
- Skip upload when App Store Connect auth is unavailable; log exact unblock steps.
- Keep commits small (single task per commit).
