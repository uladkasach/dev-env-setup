# demo: 6.1.flatpaks — a printed offer list drifted from the map

## .what

until 2026-08-14, the all-opted-out decline printed a hand-written list of
offered apps, three lines below the very block that forbade exactly that shape.

## the trace

the decline's first argument read `"spotify, datagrip and slack"` — a
hand-written list, separate from `GROVE_FLATPAK_REF`, the map this file already
declares as the one source for offered names.

it was a PRINTED list, the worse half of the drift: a stale header reads as
prose a reader may doubt, but a runtime line reads as the box's own account of
what it offers. a fourth app added to the map would have been installable,
offerable, and absent from the one sentence a human meets when they opted into
none of them.

## the fix

both arguments to the decline now derive from `GROVE_FLATPAK_REF` in one pass.
the prose is a VIEW of the map, never a second cut of it — the two cannot
disagree even in principle (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

## .see also

- `6.1.flatpaks/_.sh` — the bundle this measurement fixed
- `rule.require.identical-bundle-composition`
