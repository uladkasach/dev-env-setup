# gotcha.2-1-toolkit.demo=unzip-cascade-and-per-machine-gates

## .what

the dated measurements behind `2.1.toolkit/provision.upsert.sh`'s essential/comfort split —
why `unzip` is essential though no bundle names it in a body, and why `xclip` installs on a
headless box rather than behind a per-machine gate.

## m1 — one absent 200kb tool, three broken steps, misdiagnosed as "pnpm is broken"

a fresh ubuntu 24.04 grove does not ship `unzip`. both prior images happened to carry it.
its absence went unnoticed until three later steps depended on a tool nobody installed:
fnm's own installer surfaced it first — it reported unzip absent and declined — which
cascaded into the robot-brain install, whose every `pnpm` call then failed. the diagnosis
that surfaced first was "pnpm is broken"; the cause was one absent 200kb tool three bundles
downstream never declared as their own dependency.

## m2 — every "has a screen" gate this repo wrote confused EFFECT with HOLD

`xclip` needs an X display to move a selection; on a headless grove it stays inert — a
~100kb tidiness question, never a defect. a per-machine install list looked like the fix.
every such gate this repo has written confused the tool's EFFECT (inert without a display)
with whether it should be HELD on the box at all. one list, installed everywhere, is cheaper
than a second list to keep in sync (`rule.require.identical-bundle-composition`).

## .see also

- `rule.require.bundle-as-sole-declaration` — why `curl` is essential though unused here
- `rule.forbid.two-writers-on-one-artifact` — why `gnupg` is not guarded at each call site
- `rule.require.identical-bundle-composition` — the one-list-everywhere principle m2 restates
