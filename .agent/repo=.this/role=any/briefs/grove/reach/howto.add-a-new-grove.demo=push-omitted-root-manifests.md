# demo: add-a-new-grove — the root manifests a `src/`-only push once left behind

## .what

`howto.add-a-new-grove.md` step 4 requires `--from .`, never `--from src/`, when a push
carries the repo to a fresh grove. these are the dated measurements that show what a
partial push cost, and how the fix moved from doc to tool.

## m1 — a `src/`-only push left five root-level manifests behind

- five paths sit at the repo root, beside `src/`, and the bundle tree reads every one:

  | path | read by | bites on a grove? |
  |---|---|---|
  | `package.json` | `5.1.node` — the pnpm pin (`packageManager`) | **yes** |
  | `.nvmrc` | `5.1.node` — the node pin | **yes** |
  | `.agent/` | `5.13.reach` — calls `rhx aws.reach.set`, a `repo=.this` skill | **yes** |
  | `codium/sync.settings.yml` | `6.2.codium` | no — declines on cloud |
  | `assets/kitty-icon.png` | `4.3.2.emulator` | no — but not by a decline, see m2 |

- `.agent/` is the one a grep will not find: the first two paths are read through a path
  expression (`$(dirname "$GROVE_SRC")/package.json`), so grep names them. `.agent/` is read
  through a skill invocation — the phase says `rhx aws.reach.set`, and the dir that answer
  lives in appears in no argument, no import, no declaration
  (`gotcha.a-tool-found-by-path-answers-only-a-human`)
- six briefs each documented this one seam separately — `term=asset`, `term=shim`,
  `term=drift`, `howto.rhx-upgrade`, `howto.restore-kitty-session`, and this table — six
  records of a defect is what a repo produces instead of one fix
- ⇒ fixed 2026-08-12: `git.grove.push` now skips `.git`, `node_modules`, `.log`, `.temp`,
  and `.agent/.cache` on both carriers, and prints that list on every run, so `--from .`
  carries the repo in one push

## m2 — the kitty-icon row was true of its siblings and false of itself, read 2026-08-14

- the table above once read *"no — declines on cloud"* for the kitty-icon asset; one grep
  disproved it — `4.3.2.emulator` carries no `GROVE_ENV_SERVER` gate at all, unlike its
  siblings `4.3.3.launcher` and `4.3.4.snapshot`, which both decline on cloud
- the icon step therefore RUNS on a grove, finds no asset, and emits a `🌙`
  (`configure.upsert.sh:654`)
- ⇒ the outcome reads the same — the bundle continues — but the mechanism differs, and the
  difference is what a reader acts on: a decline needs no asset ever, while a `🌙` means the
  path was tried and the file was absent. the printed reason, *"no custom icon asset"*, is
  mis-scoped on a grove — the checkout is fine, and the TRANSPORT is what cannot carry the
  file

## m3 — an absent `package.json` cascaded into 5 of 12 claims, fresh grove 2026-08-12

- the first apply on a fresh grove raised 12 claims; 5 traced to the one absent
  `package.json`:
  ```
  5.1.node   ✋ this checkout declares no pnpm version
  5.3.brains ✋ pnpm is absent — the robot brains cannot install
  5.4.gh     ✋ AND rhx is not on PATH, so the rack cannot even be read
  5.10.repos ✋ gh is present but unauthed — cannot list org repos
  5.13.reach 🌙 declined — rhx is absent
  ```
- each downstream claim named a fix for its OWN bundle, so a top-down reader of the list
  repairs four innocent bundles and never reaches the cause (`rule.require.solve-at-cause`)
- ⇒ that whole cascade was one flag. a doc that lists what a tool omits is a hazard every
  future caller still meets — the fix belongs in the tool, not the doc

## m4 — `.agent/` alone was not enough; the CWD decided the answer too

- rhachet links a `repo=.this` role relative to the git root it runs from, so the same
  command answered two ways on one box, one minute apart:
  ```
  cwd = $HOME             ✋ no skill "aws.reach.set" found in any linked role
  cwd = the checkout root ✔ the skill itself answered
  ```
- ⇒ `5.13.reach` now runs its call under `env -C "$checkout"`, as `5.12.rack` already did.
  to read which half is broken on a given box:
  ```sh
  rhx git.grove.send <name> --reply --play diagnose.grove-reaches-this-repos-skills
  ```

## .see also

- `howto.add-a-new-grove.md` — the current procedure these measurements back
- `gotcha.a-tool-found-by-path-answers-only-a-human`
- `rule.require.solve-at-cause`
