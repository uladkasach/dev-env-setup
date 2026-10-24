# F11 — the shared-reader refactors are deferred to a dream, not done on this route

- fork: do r11's structural nitpicks on this route vs catch them with their shape and ship
  - split the pin into its own root-owned leaf bundle, so a failed build no longer skips tpm,
    plugins and conf
  - fold `5.8.docker` and `5.18.openhours` onto `1.6.7.linger`'s readers
  - narrow `sysctl --system` to the coredump drop-in
  - mark a ✔ read through a fixture env seam
  - named flags in `pin_fetch`/`pin_build`/`pin_install`
  - one `binary_*` seam, one pinned-clone op, one verified fetch
- taken: defer, all of them, to `.dream/2026_10_23.grove-provision-shared-readers.dream.md`
  (linked from this route's `dreams/`), each with its shape
  - SAFE yes; CLEAN no: each moves code across bundles this route never opened (docker,
    openhours), or re-cuts the bundle tree (a new leaf under `2.8.tmux`), or changes a
    contract the plays stub by position. each wants its own red/green pass
  - none ships a harm today: the pin's verify still ✋s when the build fails; the two other
    linger readers grant their own seat; the sysctl call reads its knob back
  - the one with a nameable cost — a failed pin build leaves a root seat with no conf, tpm or
    resurrect until the next good apply — is bounded: the floor keeps a duct, the verify
    names the pin, and the next apply converges the rest
- rework: clean — each item is additive to what ships here; no code built on this route
  depends on their absence
- confidence 80%: the leaf split is the item a director may want now, since it turns one
  failed fetch into a smaller red
- where: the dream; `2.8.tmux/provision.upsert.sh` (`provision_upsert`)

## re-asked i006 (r11), two items, held
- **the pin leaf split, with a new argument**: phases chain, so a non-zero `provision.upsert`
  puts `2.8.tmux` into `BUNDLE_BROKEN` and its `configure.upsert` is skipped on that apply
  - held: the argument names the cost F11 already priced — one failed fetch or compile leaves
    a root seat without conf, tpm or resurrect until the next good apply. the floor keeps a
    duct, the verify names the pin, and the next apply converges the rest
  - the split adds a top-level slug and moves `binary_*`, `pin_*`, `pin_floor` and
    `binary_owed` across a bundle boundary; that wants its own red/green pass over every
    tmux play, which this route's rounds do not hold
  - 🟡 the argument raises the item's rank in the dream to first; confidence the director
    wants it now: 50%
- **one reader of "where the plugins live"**: four readers coincide today because tpm
  derives its root from its own entrypoint; they part only if the conf's `run` path moves
  - held: no harm ships until the `run` path moves, and that edit lands in this same
    bundle, where the verify's "absent" red would surface it on the first plan
  - caught as dream item 9 with its shape (`plugin_root_of_conf`, asked by upsert and both
    verifies; the asked root kept as a cross-check)

## re-asked i008 (r11), held — and the split is now the director's call
- the cascade reaches a CREW seat too: its `bundle.root.owns` declines the pin, its verify ✋s
  `adrift`, and `configure.upsert` is skipped — so a crew seat's conf, plugin pins and live
  source wait on the ground seat's build, and again on every pin bump
  - this is a larger cost than F11 priced, and r11 grades it `better` because the ✋ names the
    ground seat and one act clears it; it turns `urgent` if a conf change must reach crew seats
    before the pin does
  - held here: the split re-cuts `2.8.tmux` into a parent with two leaves (as `4.3.kitty`), over
    every tmux play, on a stone whose review rounds are spent. confidence the director wants it
    in this PR: 50%. its shape is dream item 8
- also held, each caught as a dream item with its shape: one walk per live socket (10), one pin
  table (11), keyrackd's linger read (12), the narrower `systemd-sysctl` of the drop-in (5),
  and `binary_owed`'s `${GROVE_ENV_SERVER:-}` default — unreachable, since
  `grove.env.sh` resolves the tier or exits 2 before any bundle runs

## done i006 instead of deferred
- the tier gate: `provision_upsert` asks `binary_owed` once; 1a and 1b are its two arms
- the mute count no longer cancels the build count: each claim owns its own (arms E and F,
  red then green)
- an unpinned plugin refused in `configure.upsert`, before tpm clones it
  (`prove.tmux-configure-refuses-an-unpinned-plugin`, red then green)
