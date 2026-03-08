# Grainfield Mode Implementation Plan

## Objective
Add an optional **Grainfield mode** to Nearfield that supports:
1. Primary node as input
2. Repeater nodes
3. Graceful fallback to original Nearfield behavior

## Scope Breakdown

### A) Primary Node as Input
- Add mode config enum (`nearfield`, `grainfield`) and runtime switch.
- Designate one peer as `primary` source for grain payload/input.
- Serialize primary payload over Multipeer channel (versioned message).
- Validation: if payload stale/missing, mark primary unavailable.

**Acceptance criteria**
- With Grainfield mode enabled and a primary peer present, the app receives and applies primary input.
- If primary disconnects, app reports unavailable state within 1s.

### B) Repeater Nodes
- Define repeater role metadata and capability handshake.
- Implement repeater receive -> transform -> forward loop.
- Add hop-limit / loop guard token to prevent routing loops.
- Track per-repeater latency and packet loss in debug overlay/log.

**Acceptance criteria**
- Two+ repeater nodes can relay primary signal to a distant peer.
- No infinite forwarding loops.
- Basic metrics visible for route health.

### C) Graceful Fallback to Original Nearfield
- Keep existing proximity-driven harmonic engine unchanged as baseline path.
- Auto-fallback triggers:
  - no primary
  - repeater chain invalid
  - Grainfield decoding error threshold exceeded
- Surface fallback reason in UI/debug state.

**Acceptance criteria**
- In any Grainfield failure condition, app returns to original nearfield behavior without restart.
- Audio continuity: no hard mute longer than 300ms during fallback.

## Suggested implementation order
1. Feature flag + mode plumbing
2. Primary input path (no repeaters)
3. Repeater routing
4. Fallback + instrumentation
5. UX polish + QA matrix

## QA matrix (minimum)
- 2 devices, Grainfield ON, primary only
- 3 devices, one repeater
- 4+ devices, chained repeaters
- primary leaves mid-session
- repeaters flap connectivity
- Grainfield OFF (baseline regression)
