# gotcha.command-v-answers-a-function

## .what

`command -v <name>` exits 0 and answers the bare NAME when a shell FUNCTION of that name is in
scope — even on a box where no such binary exists anywhere on PATH.

this repo declares shell functions that deliberately share a name with a real binary, and
several are `export -f`'d, so a non-interactive `bash` inherits them:

| function | declared in | wraps |
|---|---|---|
| `nvim` | `src/bash_aliases.sh` | a memory cap, so a runaway nvim cannot freeze the machine |
| `usql` | `src/bash_aliases.sh` | a `--key` flag that fetches a dsn from keyrack |
| `npm` / `npx` | `src/bash_aliases.sh` | routes to pnpm in a pnpm project |
| `tsx` | `src/bash_aliases.sh` | `npx tsx` |

so any `*.verify` phase that asks `command -v` about one of those names is answered by the
**alias file**, not by the box.

## .the two measurements

both on this laptop, 2026-07-30.

**1 — the wrong PATH.** `4.5.nvim.provision.verify` read `command -v nvim`, got the literal
string `nvim`, and `readlink -f nvim` resolved that against `$PWD`. it reported that nvim lived
in the WORKTREE directory, while `type -a nvim` showed the real binary at `/usr/local/bin/nvim`
— the pinned build, correct all along. the grove, which exports no such function, passed the
same check. **the check disagreed with itself across two healthy boxes.**

**2 — the wrong defect, so the wrong fix.** `5.11.usql.provision.verify` read
`command -v usql`, was told yes, went on to read a version, and reported:

```
✋ usql is on PATH at the WRONG version
   ⇒ want 0.19.14; it says: no readable version
```

the truth: `usql --version` exited **127, command not found**. no usql binary existed. the phase
told a reader to reconcile a version when the fix was to install the thing.

that is the worse of the two. a wrong path is visibly odd; a plausible-but-wrong defect sends a
reader down a road that does not exist.

## .why a per-site `unset -f` is the wrong fix

an inline `unset -f nvim` at the caught call site was measured forgettable, twice:

- a **second** call site in the same bundle (`4.5.nvim.configure.verify`) kept the defect
- `5.11.usql`, written later with the lesson fresh, was written with the defect

a per-site guard is a rule you must remember to apply, at a site you must remember to notice.

## .the fix — one helper, declared once

`src/bundle.upgrade.sh` declares:

```sh
bundle.bin.of() { ( unset -f "$1" 2>/dev/null; command -v "$1" 2>/dev/null ); }
```

a phase either routes through it or plainly does not, which is a thing a reader can see
(`rule.require.solve-at-cause`).

the **subshell** is load-bear: an `unset -f` in the caller's shell would delete the human's
alias for the rest of the run. the blindness must be local to the question.

## .the shape to write

```sh
local bin
bin="$(bundle.bin.of usql)"
[[ -n "$bin" ]] || { echo "   ✋ usql is absent from PATH" >&2; return 1; }

local live
live="$("$bin" --version 2>/dev/null | head -1)"
```

note the second half: once you hold the path, **run the path**. a bare `usql --version` would
run the wrapper again, and for `nvim` the wrapper applies a memory cap — so a headless load test
by name tests the cap, not the editor.

## .the message owes the human the alias

when the binary is absent but the alias is not, say so. the human's experience is not "command
not found" — it is a command that resolves and then fails:

```sh
echo "      ⇒ the \`usql --key\` alias still resolves, so a human sees a" >&2
echo "        command that exists and then fails — not an absent one" >&2
```

## .the general lesson

a verify's job is to report what the BOX holds. any probe that a *config file* can answer is not
reading the box — it is reading the config, and will pass on a machine that holds the config and
no tool at all.

this is the same failure as `4.5.nvim`'s original design note: a marker present in a file proves
the bytes arrived, not that the capacity exists.

## .enforcement

- `command -v <name>` in a `*.verify` phase, where `src/bash_aliases.sh` declares a function of
  that name = **blocker** — use `bundle.bin.of`
- a phase that resolves a binary path and then invokes the bare NAME anyway = **blocker**
- a new function in `bash_aliases.sh` that shadows a binary name, with no matching audit of the
  verifies that probe it = **blocker**

## .see also

- `rule.require.upgrade-entries-verify-themselves` — what a verify is for
- `gotcha.pipefail-grep-q.md` — the other class of defect that hides inside a verify
- `rule.require.bounded-probes-in-verifies.md` — the third
- `rule.require.solve-at-cause` — why the helper, not the per-site guard
