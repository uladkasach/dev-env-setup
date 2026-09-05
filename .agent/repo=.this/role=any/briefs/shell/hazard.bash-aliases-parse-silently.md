# hazard: a broken `bash_aliases.sh` fails SILENTLY, and takes every alias with it

## .what

`src/bash_aliases.sh` is sourced, never executed. a parse error anywhere in the file kills
**the whole file** — every alias and function after the fault, and often before it too. and
because a login shell sources it with output discarded, the failure is invisible: you get a
prompt, no error, and a shell where `brains.auth.usage` and every other alias simply do not
exist.

> a syntax error here does not break one alias. it breaks all of them, and says so to no one.

## .the bite (2026-08-31)

a new alias was appended with **no trailing newline**, so it glued itself to the next
section's comment:

```sh
alias brains.auth.usage='_brains_auth_usage'# make it easy to speed test internet connection (25MB download via Cloudflare)
```

a `#` that follows a quote with no space is **not** a comment marker — it is part of the
word. so the parser read `_brains_auth_usage#` as the alias body, then tried to run
`make it easy to speed test internet connection (25MB download via Cloudflare)` as a command.
the bare `(...)` is a subshell in the middle of a simple command → parse error → the entire
file dead.

it survived several rounds of peer review, because reviewers read the diff, and the diff
looked fine. only a `source` surfaced it.

## .the rule

> after any edit to `src/bash_aliases.sh`, source it. a diff that reads well proves no more
> than that it reads well — only the parser has an opinion that counts.

```sh
source src/bash_aliases.sh && echo "syntax ok"
```

this both parses the file **and** loads the functions, so the very next command can exercise
what you just changed. a clean source is the cheapest possible proof, and there is no reason
to skip it.

## .why `zsh -n` is not the move here

`zsh -n` parses without execution, which sounds ideal — but two things spoil it:

- it is **not on the pre-approved command list**, so it costs a permission prompt
- the file is `bash_aliases.sh`, and the login shell is zsh; the two disagree on enough
  grammar that a `-n` pass under the wrong dialect can report a fault that is not real, or
  miss one that is

`source` runs under the shell that will actually read the file in production, so it tests the
thing you care about. use it.

## .the tells to watch for

| tell | what it means |
|------|---------------|
| `unknown file attribute: N` | the parser is mid-word where you expected a comment — look for a `#` glued to a quote |
| an alias "does not exist" after sync | the file failed to parse; the alias was never defined |
| an error naming a line far from your edit | the fault is usually ABOVE it — a missing newline or unclosed quote earlier |

that last row is the one that wastes the most time. the reported line is where the parser
finally gave up, not where the mistake is.

## .a cousin trap: `local a=$1 b=$a` never works

not a parse error, but the same family — it reads correctly and behaves otherwise:

```sh
_snap() {
  local name="$1" file="$SNAPS/$name.snap"   # 👎 $name is EMPTY here
}
```

`local` is a **command**, so the shell expands every one of its arguments *before* the
builtin runs. at expansion time `name` is not yet assigned, so `$name` is empty — and under
`set -u` it is an unbound-variable error that kills the run.

```sh
_snap() {
  local name="$1"
  local file="$SNAPS/$name.snap"             # 👍 its own statement
}
```

the tell is an `unbound variable` error that names a variable you assigned on that very line.

## .append with care

when you add to the end of a section, confirm a newline separates your last line from
whatever follows. the `Write`/`Edit` tools add none for you, and the failure is invisible in
a diff — the two lines render as one, but the eye reads them as two.

## .see also

- `rule.require.repo-as-source-of-truth` — why the file is edited here, never on the host
- `howto.setup-from-worktree.md` — how the file reaches `~/.bash_aliases`