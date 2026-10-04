# demo: 5.17.yq — the apt gap, the two programs, and the pin that drifted

## .what

three measurements shaped `5.17.yq`: why it is a bundle rather than an apt name, why
the apt package is a different program, and why its version is declared once.

## the apt gap — measured 2026-09-11

`yq` was first proposed as a name on `2.1.toolkit`'s apt line. a name there must be a
package EVERY box class carries, and it is not:

| box class | release | `apt-cache policy yq` |
|---|---|---|
| a grove | jammy | **no candidate at all** — not universe, not backports |
| a laptop | noble | `3.1.0-3` |

⇒ an apt name that resolves on one box class and not the other cannot meet
`rule.require.identical-bundle-composition`. a pinned static binary is the SAME
artifact on every box, so it can.

### ⛔ and NOT pipx, which is the repair that tempts

pipx DOES reach both classes, and that reach is the trap: it buys it with a python
runtime, a venv, and a resolver this repo would then own. the go build needs no
runtime at all, so it wins on both axes. `rule.avoid.python-runtimes` carries the
full argument.

## the two programs named `yq` are NOT the same program

| build | what it is | filter syntax |
|---|---|---|
| mikefarah (**ours**) | a go binary, yaml-native | jq-like |
| apt `python3-yq` | a python wrapper around `jq` | jq, via json |

a laptop that ever took the apt one carries a SECOND `yq` at `/usr/bin/yq`.
`~/.local/bin` precedes `/usr/bin` on this repo's PATH, so ours wins — ⚠️ **and the
verify does not rest on that**: it reads `bundle.bin.at`, which names the file rather
than a query of PATH order.

## the pin that drifted — `5.11.usql`, 2026-08-13

the version was typed into BOTH the upsert and the verify. the two drift the instant
one moves:

- a bump of the upsert left the verify behind
- so a **correct** install reported `✋ the WRONG version`
- and its fix-text named a re-apply that changed no state — the box was already right

⇒ the pin and the check must read the SAME variable, which is why
`GROVE_YQ_VERSION` is declared in the bundle's `_.sh` and read by both phases.

### and the DIGEST does NOT move with it

the digest stays in the upsert. a verify reads a binary already on disk, where a
digest describes a file that is gone — so it has one reader, and one reader means one
home (`rule.prefer.most-common-denominator`).

## .see also

- `5.17.yq/_.sh` — the declarations these measurements justify
- `rule.require.identical-bundle-composition` — the rule the apt gap breaks
- `rule.avoid.python-runtimes` — the full pipx argument
- `rule.prefer.most-common-denominator` — why the digest sits one level down
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false ✋ an absent yq buys the
  cycles gate, and the false ✋ the drifted pin bought the verify
