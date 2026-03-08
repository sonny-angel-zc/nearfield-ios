# Nearfield App Priority Queue

> Used by `scripts/overnight_loop.sh`.
>
> Format:
> `- [ ] P1 | owner | slug | command`

## Ready
- [x] P0 | overnight | grainfield-data-model | echo "create Grainfield session model TODO in code/doc"
- [x] P0 | overnight | grainfield-primary-input-plumb | echo "wire primary node input path behind feature flag"
- [x] P1 | overnight | grainfield-repeater-routing | echo "add repeater node routing + transforms"
- [ ] P1 | overnight | fallback-nearfield-behavior | echo "ensure fallback to current nearfield audio path"
- [ ] P1 | overnight | ux-polish-debug-surface | echo "improve diagnostics: mode, peers, active route"

## Notes
- Replace each `echo ...` with a real command or script once implementation command is defined.
- Keep each command idempotent and limited in scope.
