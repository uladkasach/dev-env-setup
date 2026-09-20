# howto.opt-into-openhours

## .what

the open-hours gate closes the GLOBAL commit and radio gates inside a declared window and
opens them outside it. it is **opt-in**: there is no skill and no flag — you edit five lines
in the tree, then apply.

## .the whole recipe

### 1. edit five lines

`src/grove.provision/5.devtools/5.18.openhours/_.sh`

```sh
GROVE_OPENHOURS_ENABLED=true           # ← the opt-in switch
GROVE_OPENHOURS_DAYS="1-5"             # mon=1 .. sun=7, CONTIGUOUS range only
GROVE_OPENHOURS_FROM="08:00"           # inclusive
GROVE_OPENHOURS_TILL="20:00"           # exclusive
GROVE_OPENHOURS_ZONE="America/Chicago" # PINNED — every box obeys it
```

### 2. apply, once per box

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
| change the hours | edit the same lines, re-apply |
| turn it off | `ENABLED=false`, re-apply — it removes the timer and its files |
| check a box | `rhx grove.provision --what 5.18.openhours --mode plan` |

⚠️ **every box, or the gate has a hole.** a grove left open while the laptop closes is a box
that still takes commits. the bundle declines nowhere, and each seat carries its own `$HOME`
— so each is pushed and applied separately (`term=seat`).

⚠️ the grove send uses the path form deliberately — a grove's `rhx` resolves no repo skill
(`rule.forbid.the-driver-by-path`, carve-out 3).

## 🛑 .it is NOT the `--include` opt-in, and the difference is load-bear

this repo has **two** opt-in mechanisms. they answer the same question — *did the human ask
for this?* — and they record the answer in different places:

| | `6.apps` | `5.18.openhours` |
|---|---|---|
| where the ask lives | `--include <app>`, on the command | `GROVE_OPENHOURS_ENABLED`, in the tree |
| lifespan | that ONE run | until a human edits the line |
| a bare `grove.provision` | installs no app | converges the gate |
| opt-out | skips; **never uninstalls** | **tears down** what it installed |

⚠️ so `rhx grove.provision --include openhours` is refused outright. no bundle offers that
name, and the entrypoint rejects a name the tree does not offer.

### .why a REPO edit and not a flag

`--include` is per-run. a gate wired that way would need the flag on every apply, or the next
bare apply would tear it down — and a gate a human must re-request forever is a gate they
lose. a declared state converges instead: the tree says what holds, and one command makes the
box match (`rule.require.one-command-provision`).

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

- `src/grove.provision/5.devtools/5.18.openhours/_.sh` — the declaration and its full reasons
- `term=opt-in._.choice._.md` — the `--include` mechanism, which this is NOT
- `define.6-apps-is-laptop-only` — the two-gate model `--include` belongs to
- `rule.require.one-command-provision` — why a declared state beats a per-run flag
- `rule.require.repo-as-source-of-truth` — why the schedule lives in the tree
