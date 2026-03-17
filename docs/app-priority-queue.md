# Nearfield App Priority Queue

> Used by `scripts/overnight_loop.sh`.
>
> Format:
> `- [ ] P1 | owner | slug | command`

## Ready

- [x] P0 | overnight | onboarding-flow | Improve the first-launch experience: add a brief animated onboarding screen that explains the concept (phones create harmonics when near each other), requests permissions (UWB, local network, Bluetooth) one at a time with friendly explanations, and shows a "searching for peers" state with a subtle pulse animation. Keep it minimal and beautiful — no walls of text.
- [x] P0 | overnight | audio-polish | Polish the audio engine in nearfield.html: (1) add a gentle warm-up fade when first connecting to a peer instead of abrupt gain jump, (2) smooth out distance→gain transitions with longer ramp times to avoid clicks, (3) add a subtle low-pass filter that opens up as peers get closer for a more organic feel, (4) tune the delay/reverb for a more spacious ambient sound.
- [x] P1 | overnight | visual-upgrade | Upgrade the web visualization: (1) replace the basic sphere+lines with a particle system where particles drift between connected peers, (2) add a subtle glow/bloom effect on close proximity, (3) make the background color subtly shift based on number of connected peers (dark blue → warm purple → golden), (4) smooth all animations with easing.
- [x] P1 | overnight | peer-names | Add peer identity: let users pick a display name on first launch (stored in UserDefaults), transmit it via MultipeerConnectivity session metadata, and show peer names as floating labels in the visualization near each peer's node.
- [ ] P1 | overnight | haptic-feedback | Add subtle haptic feedback using UIImpactFeedbackGenerator: light tap when a new peer is discovered, soft pulse that intensifies as peers get very close (<0.3m), and a gentle notification when a peer disconnects.
- [ ] P2 | overnight | debug-overlay-toggle | Add a hidden debug overlay (triple-tap to toggle): show UWB session state, per-peer distances, packet loss, Grainfield mode status, and audio engine stats. Use a translucent dark overlay with monospace text. Already partially done in ux-polish commit — extend it.
- [ ] P2 | overnight | session-persistence | Add session recovery: if the app is backgrounded and foregrounded, gracefully re-establish MultipeerConnectivity and NearbyInteraction sessions without requiring users to restart. Show a brief "Reconnecting..." state in the UI.

## Done
- [x] P0 | overnight | grainfield-data-model | echo "create Grainfield session model TODO in code/doc"
- [x] P0 | overnight | grainfield-primary-input-plumb | echo "wire primary node input path behind feature flag"
- [x] P1 | overnight | grainfield-repeater-routing | echo "add repeater node routing + transforms"
- [x] P1 | overnight | fallback-nearfield-behavior | echo "ensure fallback to current nearfield audio path"
- [x] P1 | overnight | ux-polish-debug-surface | echo "improve diagnostics: mode, peers, active route"

## Notes
- Each task should be self-contained and not break existing functionality.
- Test builds compile before moving to next task.
- Commit after each completed task with descriptive message.
