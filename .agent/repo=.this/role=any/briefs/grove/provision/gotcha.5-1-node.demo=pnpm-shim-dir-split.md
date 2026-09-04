# demo: 5.1.node — pnpm's global shim dir moved, and the fossil it left behind

## .what

`5.1.node/_.sh` pins the org's pnpm version. it asks pnpm itself where its global shims
live — it never assumes a fixed dir. two measurements back both choices.

## m1 — one box, two live shim dirs, grove-1 2026-08-06

- pnpm's global shim dir is a function of the NEAREST `packageManager` above the cwd,
  and corepack's `pnpm` dispatcher falls back to its own global default where none is
  above:

  | cwd | packageManager found | version run | shim dir |
  |---|---|---|---|
  | the repo | `pnpm@10.24.0` | 10.24.0 | `$PNPM_HOME` |
  | `$HOME` | none | 11.20.0 | `$PNPM_HOME/bin` |

- 10.x and 11.x disagree about the global shim dir. an unpinned global default puts two
  pnpms, and two shim dirs, on one box at once
- ⇒ the fix is a pin read from the repo's own `packageManager` field, never a second
  copy of the version (rule.require.identical-bundle-composition)

## m2 — the live dir moves per-cwd, so it is ASKED, never assumed

- both answers read within one second of each other on grove-1, 2026-08-06:

  | cwd | pnpm resolved | shim dir |
  |---|---|---|
  | the repo | 10.24.0 | `$PNPM_HOME` — live |
  | `$HOME` | 11.20.0 | `$PNPM_HOME/bin` — also live |

- ⇒ a hardcoded winner is wrong by construction. the dir pnpm currently writes into is
  read from `pnpm bin -g` itself; the OTHER dir's copies are the fossils a shadow check
  names (`term=shim`)

## .see also

- `5.1.node/_.sh` — the header these measurements back
- `5.1.node/configure.verify.sh` — the 57-minute hang the same probe shape avoids
  (`rule.require.bounded-probes-in-verifies`)
- `term=shim`
