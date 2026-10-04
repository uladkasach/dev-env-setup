# the candidate claude — `claude.latest`, a parallel install beside the pin

## .what

the rationale behind `claude.latest`, rehomed from `5.3.brains/_.sh` and both provision phases
so each stays an outline (`prove.headers-carry-their-weight`). the text is the code's own,
moved verbatim on 2026-10-04.

## why a second install at all

.what = `claude.latest`, a newer cli a human can trial without moving the
  pin above. `claude` stays the pin; `claude.latest` is the candidate.
.why it cannot be expressed as a second pnpm global
  pnpm global holds ONE version per package, so "both at once" has no way to
  be said there. trialing a newer cli by a `pnpm install -g` bump is an
  all-or-nothing flip whose only way back is a re-pin — and the pin exists
  because hooks are proven whole only AT it (`gotcha.5-3-brains-pins`, 2026-10-04),
  so every guardrail in this repo rides on it.
  ⇒ the candidate gets its own prefix, and the two live side by side

## why the shim is `claude.latest` and never `claude`

🔴 .why the shim is `claude.latest` and NEVER `claude`
  `~/.local/bin` is prepended in `~/.zshrc` AFTER `.zshenv` laid down
  $PNPM_HOME/bin, so it outranks the pnpm shims in a human's shell. a file
  named `claude` there would silently become the default — the exact
  all-or-nothing flip this declaration exists to avoid. the verify reads
  for that file on every run.

`~/.zshrc` prepends `~/.local/bin` AFTER `.zshenv` laid down $PNPM_HOME/bin,
so that dir outranks the pnpm shims in a human's shell. a file named
`claude` there therefore BECOMES the default, and every check above still
reads the pnpm copy the tree declares — so the swap is invisible to all of
them, which is what makes this its own claim.
⚠️ asked on EVERY run, opted in or out. it grades a hazard about the
  DEFAULT, so the candidate's flag has no bearing on whether it applies

## why a symlink named `latest`

.why a SYMLINK named `latest`, rather than the name alone
  `latest` reads two ways: npm's dist-tag RIGHT NOW (dynamic, a network
  lookup per call), or the newest build INSTALLED HERE (static). the
  symlink makes it the second, and makes it auditable —
  `readlink ~/.local/opt/claude/latest` answers "latest as of when?"

## opt in, opt out

.how to opt OUT = set the pin to "". the next apply removes the shim, the
  symlink, and every versioned prefix — and touches the default not at all
⚠️ set this ONLY while a trial is live, and empty it once the trial settles —
  a candidate equal to the default above is a second copy of one version, and
  makes `claude.latest` a synonym for `claude`

.why teardown rather than a skip: a box opted in once and out later would
  keep a `claude.latest` no line in the tree declares, pointed at a
  version nobody reviewed. the same reason `5.18.openhours` tears down

⚠️ the claim INVERTS with the pin. an opted-out box that still carries a
  shim offers a command no line in the tree declares, pointed at a version
  nobody reviewed — so a torn-down box is CONVERGED, and residue is the
  defect this reads for

## the memory cap

⚠️ .this RESTATES the 8G that `2.7.aliases/bash_aliases.sh` gives the `claude`
  shell function, and the restatement is forced rather than sloppy: the shim
  runs from `~/.local/bin` with no shell behind it, so it can source no alias
  file and borrow no function from one — the same bind `src/machine/
  kitty_snap_lowbatt` names for its absolute path.
  ⇒ a bump wants BOTH. the twin lives at `bash_aliases.sh`, in `claude()`
.why the cap is on the shim and not merely on a wrapper
  the extant wrapper is a shell FUNCTION, so it caps a human's invocation and
  no call a tool spawns. a shim is a file on PATH, so every caller gets it

## the state reader — three states, never a presence test

.why a state, never a boolean — ONE reader, so the upsert and the verify
  cannot cut the same set two ways (`gotcha.a-check-that-cries-wolf`, m.9)
🛑 .why it reads the PIN and not merely the presence of a dir
  the prefix is built in several steps (mkdir, package.json, pnpm add), so a
  run cut partway leaves a dir that passes a presence test and holds no
  binary. a presence guard would skip it on every apply thereafter and the
  box would be unrepairable by the only command it was given
  (`define.provision-defect-shapes`, shape 6)
stdout: whole  = the pinned prefix holds a runnable bin AND `latest` names it
        half   = something under the prefix exists and one of those does not
        absent = never built

## the shim renderer

.why  = ONE renderer, so the upsert WRITES and the verify DIFFS one text —
  a shim asserted present and never CURRENT would keep an old cap, or an
  old target, with no reader to notice
⚠️ .why it names `latest` and not the pinned dir
  the symlink is the pointer a bump re-points. baked here, every bump would
  need this file rewritten too, and a box whose shim lagged would run a
  version the tree no longer declares
⚠️ .why `/bin/sh` and not bash — it is a two-branch exec with no bashism, and
  `sh` is the one interpreter present before any bundle of this repo has run

⚠️ a presence test would pass on a shim that still names the prior cap, or
  the prior target — so it is DIFFED against a fresh render of the one
  declaration it was written from

## the package.json is written, with its build approval inside

.why written: `pnpm init` is one more registry-era command whose output
  shape is pnpm's to change; this text is ours and is the same on every
  box (`rule.require.identical-commands-on-every-server`)
🛑 .why `onlyBuiltDependencies` is DECLARED here and not passed as a flag
  pnpm 10+ refuses a dependency's build scripts unless approved, and
  WITH A TTY it ASKS — which hangs the run and eats the next command
  sent down the duct (`rule.forbid.tty-as-a-proxy-for-a-human`: a duct
  HAS a tty). the global install above answers that with
  `--allow-build=`; a local prefix can answer it in the manifest, which
  is better — the approval then lives in the artifact rather than in the
  one command line that happened to install it

## `ln -sfn`

⚠️ `-n` beside `-f`: without it `ln -sf` DEREFERENCES an extant symlink to
  a dir and writes the new link INSIDE the old target, so a second bump
  would land at `v<old>/v<new>` and the pointer would never move

## the reap of undeclared prefixes

🛑 .why a reap at all: a bundle that only ADDS converges a box to every
  version this repo has ever declared rather than the one it declares
  today, and no verify on a declared row can see it
  (`rule.require.one-command-provision`, defect shape 11). each prefix is
  a full node_modules, so the residue is measured in hundreds of MB
⚠️ the declared set is DERIVED from the pin, never a skip-list of retired
  versions — a skip-list goes stale the day the next bump lands, silently

## the verify runs the shim, and asks the binary

⚠️ the SHIM is what runs, never the binary behind it — the shim is the path
  a human takes, and it carries two branches of its own
  (`rule.require.prove-the-path-the-human-runs`)
⚠️ the version is asked of the BINARY for the same reason the pin above is:
  claude's in-place updater rewrites `cli.js` and leaves package.json
  behind, so a check on the package answers ✔ on a drifted box

⚠️ a 🌙, never a ✋: this reads THIS shell's PATH, and a verify driven
  over a duct runs in a shell whose PATH is not the human's
  (`gotcha.a-tool-found-by-path-answers-only-a-human`)

## .see also

- `5.3.brains/_.sh` — the declarations, the state reader, the renderer, the upsert and the verify
- `gotcha.5-3-brains-pins.demo=publish-path-and-drift` — the pins the candidate sits beside
