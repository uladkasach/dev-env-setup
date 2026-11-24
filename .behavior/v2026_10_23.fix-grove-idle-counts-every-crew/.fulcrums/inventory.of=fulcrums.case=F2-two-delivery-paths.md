# F2 — this repo byte-owns the check on extant groves; infra keeps first-boot delivery

## .the fork
- **a** — this bundle byte-owns `/usr/local/bin/idle-hibernate.sh` + units; infra keeps its
  first-boot copy, fixed to the same logic
- **b** — this bundle adds only a drop-in pre-check beside infra's check (the stopgap's shape)
- **c** — infra drops the check; this repo becomes its sole writer

## .taken — a
- cloud-init runs at first boot only; an extant grove heals only by a rebuild, which wipes its
  root volume. so a repo that re-applies is owed the extant groves
- b leaves the cause (the trace list) in place and computes idleness twice, with two limits
- c leaves a fresh grove with no self-hibernate until its first ground apply

## .rework — dirty
the choice sets which repo owns which bytes, and the infra dispatch is built on it.

## .confidence — 75%, and why it is low
two writers on one file is what `rule.forbid.two-writers-on-one-artifact` warns of. here one writer
runs once and never again, so the bundle is the sole steady-state writer; infra's compacted bytes
still read as drift until the first ground apply.

## .risk — high

**the harm it could ship: a box that hibernates with a live crew** — the exact defect this route
repairs, reintroduced by drift. both directions ship it:

| the drift | what happens on the box |
|---|---|
| infra improves its check later; this repo does not follow | the next ground apply overwrites infra's newer logic with this bundle's older bytes — silently, since the verify cmps only against this checkout |
| this repo improves the check; infra does not follow | a fresh grove runs infra's stale check from first boot until its first ground apply — hours to days of exposure |

**why it is not low:** no gate compares the two. infra's `asShellCompacted` strips every comment
line, so the bytes never match this repo's, and a byte diff cannot even be written. only the fixture
cases each repo runs keep the two in step — and each repo runs its own.

**what would lower it** (not chosen; each is the clean half of a dirty rework):
- infra's clamp runs this repo's fixture cases against its emitted check, so a logic drift reds there
- or infra drops the check and this bundle is its sole owner — at the cost of no self-hibernate on a
  fresh grove before its first ground apply

## .where
the bundle, and the radio task to `ahbode/infrastructure`.

## .verdict
ruled (a) — 2026-11-21: this bundle byte-owns `/usr/local/bin/idle-hibernate.sh` and its units on
extant groves; infra keeps its first-boot copy, fixed to the same logic. the high risk stands as
graded; the mitigations above stay unchosen.
