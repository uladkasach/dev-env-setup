# domain.term.choice.reason: bin

## .etymology

`bin` is unix's own noun for the place a program lives — `/usr/bin`, `~/.local/bin`, `$PNPM_HOME/bin`.
every path this term ever returns ends up inside a directory literally named `bin`, so the word is
read off the territory rather than invented over it.

it was chosen over `binary` for shape: its two peer operations in `src/bundle.upgrade.sh` are
`bundle.fn.of` and `bundle.num.of`. a three-letter noun keeps the trio one column wide and one
idea deep — `fn`, `num`, `bin` (rule.prefer.symmetric-term-pairs).

## .why `which` was declined, though it names the same idea

`which` is the closest word in common use: a human who wants this fact types `which usql`. that is
exactly the problem.

`which` is a TOOL, and the tool has the defect. in zsh, `which usql` prints the shell function's
whole body; in bash it is a builtin that behaves differently again. the shadow bug this term exists
to route around is a bug you hit BY TYPING `which`.

so to name the operation `bundle.which.of` would advertise, in the name, the behavior the operation
refuses to have. a reader who trusted the name would trust the wrong semantics.

`bin` carries no tool's baggage. it names the artifact, and leaves how it is found to the body.

## .why this earned a term rather than a comment

the first repair for this defect was a comment plus an inline `unset -f nvim` at one call site. it
did not hold:

| date | site | outcome |
|---|---|---|
| 2026-07-30 | `4.5.nvim/provision.verify.sh` | fixed inline, with a long comment |
| 2026-07-30 | `4.5.nvim/configure.verify.sh` | **missed** — same bundle, same session |
| 2026-07-30 | `5.11.usql/provision.verify.sh` | **written with the defect**, lesson fresh |

three sites, two of them wrong, all within one session by an author who had just documented the
trap. a comment describes; it does not oblige. a named operation does: a phase either routes
through `bundle.bin.of` or plainly does not, and that is visible in a diff
(rule.require.solve-at-cause).

the term is what makes the obligation checkable.

## .evidence

### the misdiagnosis, measured

on this laptop, `--what 5.11.usql --mode plan` reported:

```
✋ usql is on PATH at the WRONG version
   ⇒ want 0.19.14; it says: no readable version
```

and the box answered:

```
$ type -a usql
usql () { ... rhx keyrack get --key "$key" ... }   ← a shell function
$ usql --version
usql:34: command not found: usql                    ← exit 127
```

no usql binary existed anywhere. the phase had been told "present" by `src/bash_aliases.sh`.

the harm is not that it failed — it is that it failed **plausibly**. "wrong version" sends a reader
to reconcile a pin; "absent" sends them to install. one of those roads does not exist.

### the shadowed names, enumerated

`src/bash_aliases.sh` declares five functions that share a name with a real binary, several of them
`export -f`'d so a non-interactive `bash` inherits them:

| name | wraps |
|---|---|
| `nvim` | a memory cap, so a runaway nvim cannot freeze the machine |
| `usql` | a `--key` flag that fetches a dsn from keyrack |
| `npm` / `npx` | routes to pnpm in a pnpm project |
| `tsx` | `npx tsx` |

any verify that probes one of those five names without this term is answered by the alias file.

### the second half of the lesson

to hold the path is only half. once `bundle.bin.of` returns a path, the phase must **run the path**:

```sh
live="$("$bin" --version)"     # 👍 the bin
live="$(usql --version)"       # 👎 the wrapper, again
```

for `nvim` the wrapper applies a memory cap, so a headless load test invoked by NAME tests the cap
rather than the editor. the term names an artifact precisely so it can be USED, not merely counted.

## .invariants

- a `bin` is an absolute path or the empty string — never a bare name
- the read is made in a SUBSHELL: an `unset -f` in the caller would delete the human's alias for the
  rest of the run, so the blindness must be local to the question
- a new function in `bash_aliases.sh` that shadows a binary name obliges an audit of the verifies
  that probe it
