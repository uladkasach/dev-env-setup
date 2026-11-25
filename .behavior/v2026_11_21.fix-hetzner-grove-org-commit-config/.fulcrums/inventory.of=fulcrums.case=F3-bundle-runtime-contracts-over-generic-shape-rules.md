# F3 — a bundle keeps the bundle runtime's own contracts where a generic code-shape rule reads otherwise

## .the fork

peer round i001 raised five concerns that each ask a bundle file to take the shape of a
typescript domain operation:

| concern | asks for | the bundle runtime's contract |
|---|---|---|
| r2 nitpick.2 | exit 2 from a verify on an unset org (a constraint) | `bundle.upgrade` reads a phase's exit as zero or non-zero and no finer (`src/bundle.upgrade.sh:656`); every peer verify returns 1. the runtime would read a 2 as a 1, and the ✋ line already names the human as the fixer |
| r4 nitpick.1 | `get*` / `is*` verb prefixes on bundle functions | every bundle function is `grove_provision_<slug>_<noun>`, the name `bundle.upgrade` dispatches by |
| r4 nitpick.2 · r7 nitpick.1 | one procedure per file | a bundle is `_.sh` plus one file per phase; `bundle.upgrade` sources exactly those |
| r8 nitpick.2 | snapshots of the verify's output | ⚠️ **withdrawn — the premise was false.** `play.snap.operations.sh` exists and 28 permanent plays use it; peer round i004 (r010 blocker.2) caught it. the clamp now snapshots every human-read transcript (claim 9), so this row is no longer disputed |
| r1 nitpick.4 | a zero-row check per table in `prove.org-scoped-rows` | an org may hold no arm in a given table (<org3> has no 5.26 row), so a per-table zero is no defect; and 2d predates this route |

## .taken, and why

keep the runtime's contracts. each asked shape would break the one convention every peer bundle
holds, and `bundle.upgrade` reads them by name and by file. a split of one bundle off from it is
the second-path defect `rule.require.identical-bundle-composition` exists to stop.

## .what was NOT disputed

positional args (r4 · r5 · r7 blocker.1): the repo holds a `key=value` idiom of its own
(`grove_ssh_alias_set`), so the concern was conceded and every multi-arg function this route
added now takes named args. `claim` alone keeps its form: it takes a label and a command to
run, as `timeout` does.

## .rework

clean. each is a rename, a file split, an exit code, or a snapshot file; no caller outside this
bundle and its clamp would move.

## .confidence — 85%

the runtime contract is read, not assumed (`bundle.upgrade.sh:638-661`). the open 15%: the council may
rule that new bundles start a migration toward the generic shapes.

## .where

`src/grove.provision/5.devtools/5.26.commitorgs/` · `.play/permanent/prove.org-scoped-rows.play.sh`

## .verdict

open — for the council.
