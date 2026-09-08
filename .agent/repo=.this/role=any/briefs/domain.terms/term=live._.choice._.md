# domain.term: live

term.chosen   = live
term.kind     = adj
term.synonyms.forbidden:
- runtime
- actual
- current
- effective
- in-effect
- observed

## .what
state as the machine holds it this instant — `swapon --show`, `ps`, `ss`, `/proc/swaps`. it is
rebuilt at every boot from the `declared` state, so it is a consequence, never a cause.

## .the pair
`live` is one half of a pair; its opposite is `declared` (`term=declared`). live state may be
REPORTED as context, and only when labelled transient. it must never carry a verdict
(`rule.require.judge-declared-state-not-live-state`).

## 🛑 .a live READ has a shelf life, and a DETACHED one outlives its subject

`live` means *this instant*. so a live read is a claim with a timestamp on it, and the
timestamp is the half a reader drops first.

⇒ measured 2026-08-15: three DETACHED `git.grove.provision test` runs each reported

```
├─ 0. box
│  └─ ✋ the ladder halted — 1 bundle verify did not hold
```

and each was **true when it ran and false when it was read**. the box had been repaired in
between; a live re-climb answered `✔ 129 · ✋ 0` on both seats, with no change to the box
between the two verdicts.

⚠️ this is NOT the false ✋ of `gotcha.a-check-that-cries-wolf-gets-silenced`. every one of
those checks was **correct**. what was stale is the READER's assumption that a verdict it
holds still describes the machine — the same decay `rule.require.trust-but-verify` names, on
the one kind of state that is defined to change underfoot.

⇒ **a verdict about live state is evidence about a box that may no longer exist.** re-run it,
or do not cite it. a `declared` verdict may be filed and read later; a `live` one may not.

## 🛑 .a live read through a STALE CARRIER is stale, however fresh its timestamp

the measurement above is about a verdict that AGES. this one is its mirror, and it is
harder to see: the read is taken **this instant** and is still a fact about the wrong
subject — because the CARRIER it travelled through holds state of its own.

⇒ measured 2026-08-25, on a grove whose apply had just installed the whole toolchain:

```
rhx git.grove.send <grove> --reply --what 'command -v zsh node pnpm rhx …'
   /usr/bin/zsh
   /usr/bin/git          ← node, pnpm, rhx, starship: ABSENT
```

all four were on that disk, installed minutes earlier. the duct pane's shell had started
**before** the apply, so its `PATH` is a snapshot from pane-start — and `command -v`
answers from `PATH`. one `duct.reboot` later, the same probe named all four.

### .why this is not the shelf-life case

| case | what is stale |
|---|---|
| the 2026-08-15 measurement | the VERDICT — read once, cited later |
| this one | the CARRIER — read now, through a shell older than its subject |

the second has no timestamp to check. the read was current; the pane was not. so
*"re-run it"* — the repair for a stale verdict — reproduces the same wrong answer forever.

⇒ **a probe reports a fact about the SUBJECT only where the carrier is younger than the
change.** for a duct that means `duct.reboot` first, and it is the same lesson
`gotcha.a-tool-found-by-path-answers-only-a-human` teaches one layer over: there, a
verdict about the CALLER's PATH dressed as a verdict about the box.

⚠️ and a shell is the trap because its staleness is invisible — a pane looks identical
whatever its `PATH` holds, and the answer it gives is a plausible, specific absence.

## 🛑 .a live read of a tree ANOTHER AUTHOR holds is stale before it prints

the two measurements above both fail on a subject that sat still. this one fails on a subject
that did not — and it is the shape with no repair at all in the read.

⇒ measured 2026-09-07, in this repo's own worktree. a `git status` named 8 untracked term files
and a 280-line unstaged diff, all a peer's. i read that list as the inventory of their work and
reported it as such. **90 minutes later two more files existed** — the very clamp whose absence i
had just named as the reason to withhold their change:

```
15:26:30  .play/permanent/prove.breaker-spares-cached-buffers.probe.lua
15:27:47  .play/permanent/prove.breaker-spares-cached-buffers.play.sh
```

the read was correct at its instant, through a carrier that held no state, and about a subject
that changed while the conclusion was still under composition.

### .the third shape, beside the two above

| case | what is stale | the repair |
|---|---|---|
| the aged verdict (2026-08-15) | the VERDICT — read once, cited later | re-run it |
| the stale carrier (2026-08-25) | the CARRIER — a pane older than its subject | reboot the duct, then read |
| **a live author** (2026-09-07) | **the SUBJECT — still under edit** | **none. ask the author** |

⇒ the first two are repaired by a better read. **this one is not**, because no read is fast
enough to outrun a hand still at the keyboard. a second `git status` would age the same way.

⚠️ and it is the most confident of the three. an aged verdict has a timestamp to distrust; a
stale carrier gives a suspicious absence. a fresh `git status` over a live tree gives a
COMPLETE-LOOKING list, and its incompleteness is invisible by construction —
`gotcha.a-check-that-cries-wolf-gets-silenced` m.12, where a count is true of the subset the
reader could see.

⇒ **a tree with a second author is live state, and a verdict about their work is a verdict about
live state.** report it as transient, or do not report it — the rule this term already serves
(`rule.require.judge-declared-state-not-live-state`), applied to a subject that is a person.

## .why it is bare, not `grove.live`
same allowance as its pair (`term=declared`): the word means exactly the same of a grove's
swap, a tree's session, or a tree's PATH, so it spans contexts rather than belongs to one. a
prefix would multiply one concept into three synonyms. `rule.prefer.symmetric-term-pairs` also
binds the two halves — to prefix one and not the other would break the pair.

## .refs
where the term is declared / used:
- .agent/repo=.this/role=any/briefs/evidence/rule.require.judge-declared-state-not-live-state.md

## .reason
see the ref-level cluster beside this choice:
- `term=live._.choice.reason.md` — etymology, rejected synonyms, why it may not carry a verdict
