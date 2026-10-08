# howto.opt-into-openhours

## .what

the open-hours gate closes the GLOBAL commit and radio gates inside a declared window and
opens them outside it. it is **opt-in PER BOX**, and the default is **off**: a box carries the
gate only where a human has placed a marker on it.

⇒ the two halves have two owners. the **hours** live in the tree, one declaration for every
box. the **election** — does this seat want the fence — lives on the box
(`rule.require.optin-bundles-converge-to-their-flag`).

## .the whole recipe

### 1. place the marker, on each box you want fenced

```sh
rhx machine.openhours.optin.set --why 'this seat is fenced to my hours'   # plan
rhx machine.openhours.optin.set --why 'this seat is fenced to my hours' --mode apply
```

the `--why` **content is never parsed** — only the path's presence is read, so the body is yours
for a note to your later self. `--why` is optional; a dated line is the default.

⚠️ **reach for the family, never a hand-rolled `mkdir` + redirect.** the marker's path is the
half nobody recalls, and a redirect one character off writes a file the bundle never reads — so
the next apply tears the gate down and reports success
(`rule.require.reach-for-the-skill-before-adhoc-shell`).

⚠️ a marker on one box says **no word** about any other. a grove needs its own.

read any box at any time:

```sh
rhx machine.openhours.optin.get          # election + converge, as two rows
rhx machine.openhours.optin.get --quiet  # 'in' or 'out' alone, for a caller
```

### 2. the hours, if the declared ones do not suit — edit four lines

`src/grove.provision/5.devtools/5.18.openhours/_.sh`

```sh
GROVE_OPENHOURS_DAYS="1-5"             # mon=1 .. sun=7, CONTIGUOUS range only
GROVE_OPENHOURS_FROM="08:00"           # inclusive
GROVE_OPENHOURS_TILL="20:00"           # exclusive
GROVE_OPENHOURS_ZONE="America/Chicago" # PINNED — every box obeys it
```

⚠️ these are shared by every box that opts in. there is **no per-box schedule**, by design —
one human, one day, however many seats.

### 3. apply, once per box

```sh
# this laptop
rhx grove.provision --what 5.18.openhours --mode apply

# each grove SEAT — ground first, then the camper
rhx git.grove.push <grove>.ground --from . --into git/more/dev-env-setup --mode apply
rhx git.grove.send <grove>.ground --reply --within 900 \
  --what 'bash $HOME/git/more/dev-env-setup/src/grove.provision._.sh --what 5.18.openhours --mode apply'
```

that is the whole procedure.

| you want to | do |
|---|---|
| change the hours | edit the four lines, re-apply **every** opted-in box |
| turn it off on ONE box | `rhx machine.openhours.optin.del --mode apply` — **human only**, at a terminal — then re-apply the bundle |
| turn it off everywhere | del the marker on each box, re-apply each |
| check a box's election | `rhx machine.openhours.optin.get` |
| check a box's converge | `rhx grove.provision --what 5.18.openhours --mode plan` |

⚠️ **the hole in the gate is yours to close now.** a grove left open while the laptop closes is
a box that still takes commits. a tree-wide flag closed that hole by force and cost you the
choice; the marker hands the choice back, and the hole with it. each seat carries its own
`$HOME`, so each is marked, pushed, and applied separately (`term=seat`).

⚠️ **the marker is never written by the bundle**, so an apply can neither grant nor lose your
election — and a teardown leaves it alone. that is what lets `rm` be the honest opt-out.

## 🛑 .a teardown can STRAND a closed gate — check it after

the teardown stops the converge and **opens no gate**, by design: the bundle cannot tell a block
it set from one you set by hand, and the safe direction on an unreconciled gate is closed.

⚠️ the consequence is sharp, and it bit on 2026-10-01. if you opt out while the gate is CLOSED,
the block survives the teardown — and the converger that would have lifted it at 20:00 is the
very thing you just removed. the gate then stays shut forever, and the bundle's verify reports
`✔ no gate installed`, because by its own claim the box is correctly converged.

⇒ so **read the gate after any teardown**, and lift it yourself if it is shut:

```sh
rhx git.commit.uses get                 # look for 'global: blocked'
rhx git.commit.uses allow --global      # human only — run it at a terminal
rhx radio.uses --global allow
```

⚠️ both skills refuse a caller with no tty, so an agent cannot clear this for you. that guard is
deliberate (`rule.forbid.tty-as-a-proxy-for-a-human`) — the gate moves by a human's hand or by a
schedule they declared, never by anything else.

⚠️ the grove send uses the path form deliberately — a grove's `rhx` resolves no repo skill
(`rule.forbid.the-driver-by-path`, carve-out 3).

## 🛑 .it is NOT the `--include` opt-in, and the difference is load-bear

this repo has **two** opt-in mechanisms. they answer the same question — *did the human ask
for this?* — and they record the answer in different places:

| | `6.apps` | `5.18.openhours` |
|---|---|---|
| where the ask lives | `--include <app>`, on the command | a marker file, on the box |
| lifespan | that ONE run | until a human removes the marker |
| a bare `grove.provision` | installs no app | converges the gate to the marker |
| opt-out | skips; **never uninstalls** | **tears down** what it installed |

⚠️ so `rhx grove.provision --include openhours` is refused outright. no bundle offers that
name, and the entrypoint rejects a name the tree does not offer.

### .why a MARKER and not a flag

`--include` is per-run. a gate wired that way would need the flag on every apply, or the next
bare apply would tear it down — and a gate a human must re-request forever is a gate they
lose. a placed marker converges instead: the box says what it wants, and one command makes it
match (`rule.require.one-command-provision`).

### .why the box and not the tree

a tree-wide boolean can say *every box* or *no box* — and it cannot say *this laptop but not
that grove*, which is what one human with several seats actually wants. the election is a fact
about a SEAT, so the seat holds it.

⚠️ this is **not** a per-machine bundle subset. every box still runs `5.18.openhours` and all
its phases; what differs is what the bundle converges TO. the distinction is the whole subject
of `rule.require.optin-bundles-converge-to-their-flag`, and it is what keeps
`rule.require.identical-bundle-composition` intact.

### 🛑 .why opt-out TEARS DOWN, where `6.apps` merely skips

`grove_optin`'s *never uninstalls* is right for an app — a forgotten `--include` must not be
destructive. it is wrong for a GATE: a box opted in once and out later would keep a live timer
that blocks commits, with no line in the repo to declare it.

⚠️ **and the teardown opens NO gate.** a human may have closed one by hand, and the safe
direction on an unreconciled gate is closed. opt-out means STOP RECONCILING, never OPEN.

## .the two bounds the schedule carries

⚠️ **the days are a contiguous RANGE**, so `mon,tue,thu` is inexpressible. a split week needs
a set parser this bundle does not have.

⚠️ **the zone is PINNED and every box obeys it**, whatever its own clock reads. the timer
carries no `OnCalendar` for exactly this reason — an `OnCalendar` reads the BOX timezone, so a
grove on UTC and a laptop on local would enforce two windows from one declaration.

## .the cadence, and what it costs

the timer re-asks **twice an hour**, so a boundary can land up to 30 minutes late. that is the
declared trade: the gate is a courtesy fence around a human's hours, never a security control.

⇒ a box that must close ON the minute needs a different mechanism, never a smaller interval —
the drift is bounded by design.

## .what to read after an apply

the verify prints twelve claims; these are the two a human acts on:

```
• gate right now — commit: open · radio: open
🌙 the CONVERGE leg is unproven on a box with no drift
```

the 🌙 is honest rather than a defect: the converge leg fires only when the gate disagrees with
the clock, so an apply outside a boundary cannot exercise it. the next real crossing proves it:

```sh
journalctl --user -u machine_openhours_reconcile.service --since today
```

## .see also

- `machine.openhours.optin.{get,set,del}` — the family that wraps the marker. ask the skills dir
  for the current set rather than trust this line (`rule.require.wrap-cli-in-skills`)
- `src/grove.provision/5.devtools/5.18.openhours/_.sh` — the declaration and its full reasons
- `rule.require.optin-bundles-converge-to-their-flag` — the tactic this bundle is the reference for
- `term=opt-in._.choice._.md` — the `--include` mechanism, which this is NOT
- `define.6-apps-is-laptop-only` — the two-gate model `--include` belongs to
- `rule.require.one-command-provision` — why a declared state beats a per-run flag
- `rule.require.repo-as-source-of-truth` — why the schedule lives in the tree, and the marker does not
