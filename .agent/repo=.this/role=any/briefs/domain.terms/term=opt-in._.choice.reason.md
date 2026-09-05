# domain.term.choice.reason: opt-in

## .etymology

every other bundle in the tree converges a box toward a **fact**: a box needs a shell, a
git, a node. `6.apps` installs a **preference**, and a human's taste is not a fact about
the machine.

so the tree declares what is AVAILABLE and the command declares what is WANTED. `opt-in`
is the adjective for that split: the bundle offers, the human names, and silence means no.

the word is taken as-is from its ordinary sense — a thing you are out of until you say
otherwise. it earns its place here because it names the DEFAULT, which is the one fact
every rejected synonym below leaves unsaid.

## .disputes

### dispute: optional — raised 2026-08-14 — status: RESOLVED (keep `opt-in`)
- raised.by  = the human, at the moment the change was asked for
- claim      = *"can we enbrief that those 6.apps are optional?"* — the plain word, and the
               one a reader reaches for first
- counter    = `optional` says a thing MAY be absent. it is silent on the DEFAULT, and the
               default is the whole content of this change. `6.apps` was already
               "optional" in that loose sense on 2026-08-13 — a grove declined all five —
               while a laptop installed all seven unasked. so `optional` cannot tell the
               before-state from the after-state, which is exactly why a brief that used
               it would have been true of a grove and false of a laptop.
- resolution = keep `opt-in`; record `optional` as a forbidden synonym. the brief that
               was asked for is `define.6-apps-is-laptop-only.md`, and it says `opt-in`.

### dispute: opt-out — raised 2026-08-14 — status: RESOLVED (a DISTINCT concept, forbidden here)
- raised.by  = the author, while the decline text was written
- claim      = the mirror flag reads symmetrically and would let a laptop drop one app
               without a list of the six it keeps
- counter    = an opt-out default is ON, so a forgotten flag would UNINSTALL — and
               `rule.require.safe-by-default` forbids exactly that. the two words name
               real, opposite policies; this repo runs one of them, and to let the other
               stand as a synonym would make the decline text ambiguous about whether an
               absent name removes an app.
- resolution = `opt-in` is the policy; `opt-out` is forbidden as a synonym for it.
               `define.6-apps-is-laptop-only.md` states the non-destructive half
               explicitly (*"an app dropped from the flag is simply not upgraded"*).

### dispute: feature-flag / toggle — raised 2026-08-14 — status: RESOLVED (keep `opt-in`)
- raised.by  = the author
- claim      = the industry words for "a thing that is off until switched on"
- counter    = both name a branch on STORED config, read at run time, that changes what
               code DOES. `--include` is a per-run argument that changes what the run
               CONVERGES, and it stores no state — a second run with no flag installs no
               more and removes no less. to borrow the flag vocabulary would invite a
               reader to hunt for a config file that does not exist.
- resolution = keep `opt-in`; record both as forbidden synonyms.

## .evidence

### the contract it composes

| what | where |
|---|---|
| `--include <app>[,<app>…]` | `src/grove.provision._.sh` — the parser, and the refusal |
| `GROVE_OPTIN_APPS` | built by each bundle's `_.sh` as the tree is sourced |
| `grove_optin <app>` | `src/bundle.upgrade.sh` — the predicate a bundle asks |
| `grove_optin_decline` | `src/bundle.upgrade.sh` — the 🌙 that names its own fix |

### the invariant that makes it checkable

> the set of names `--include` accepts is the set the BUNDLES offer, and there is no
> second copy of it.

a list beside the parser would go stale the day an app is added — with no signal, since a
name absent from it is indistinguishable from a typo. so the entrypoint validates against
`GROVE_OPTIN_APPS`, which the bundles append to, and a typo is refused with exit 2 BEFORE
any bundle runs (`rule.prefer.prevent-over-correct`).

⚠️ the refusal is not a nicety. without it, `--include codum` declines every bundle,
installs the same set a bare run installs, and reports `🌲 done` — the human asked for an
app, got none, and was told the box converged (`rule.forbid.failhide`).

### the measurement — 2026-08-14, a laptop (`local@unix`)

```
$ rhx grove.provision --what 6.apps --mode plan
      ├─ 6.apps
         ├─ 6.1.flatpaks
            🌙 spotify, datagrip and slack — not opted in; add it with: grove.provision --include datagrip,slack,spotify
         …
```

5 bundles, 5 declines, zero packages — on the box class that installed all seven the day
before. proven both directions by `prove.optin-gates-bite`, which reads a bare plan, an
`--include`d plan, a typo (exit 2), and confirms the offered set is derived rather than
listed.

### what the term retired

`6.4.protonvpn` is the bundle that earns the word. its download url answered **404 for
months** and no run could see it: a grove DECLINED the install and a laptop SKIPPED it on
an already-present binary, so both printed a clean result about a path that could not work.

⇒ an app a human never asked for is an app whose failure nobody reads.

## .see also

- `define.6-apps-is-laptop-only.md` — the two gates, and the per-app table
- `term=decline._.choice._.md` — the 🌙 an unopted bundle prints, and why its REASON matters
- `term=gate._.choice._.md` — what a gate is, and why two of them stack here
- `rule.require.bundle-as-sole-declaration` — why the offered set is derived
- `rule.require.safe-by-default` — why the mirror policy is forbidden
