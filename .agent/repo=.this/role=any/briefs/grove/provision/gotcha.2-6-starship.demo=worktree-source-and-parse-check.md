# gotcha.2-6-starship.demo=worktree-source-and-parse-check

## .what

the dated measurement behind `2.6.starship/configure.upsert.sh`'s `$GROVE_SRC` source, and
the parse-vs-grep and stream-routing rationale behind `configure.verify.sh`.

## m1 — a defaulted var installs MAIN's file from inside a worktree

measured on this laptop, 2026-07-30, a run driven out of a worktree:

```
• starship.toml upgraded from /home/vlad/git/more/dev-env-setup/src
```

every other bundle in that same run read the worktree; this one alone read main. no line in
this repo sets `DEV_ENV_SETUP_DIR`. a `${DEV_ENV_SETUP_DIR:-…}` default takes its fallback
on every run and installs main's file. the copy still SUCCEEDS. the symptom is a silent
"my edit had no effect" — never an error. `$GROVE_SRC` is this run's own checkout and carries
no such fallback (`howto.install-configs-from-a-worktree.md`).

## verify: why `print-config`, not a `grep` for a known key

a grep proves a string sits in the file; it says no word about whether the program can PARSE
it. `starship print-config` reads and re-emits the actual config, so a parse failure surfaces
and the read writes no state.

## verify: why the exit code alone is not trusted

`print-config` exits non-zero for two unlike reasons — the config failed to parse, or the
subcommand is absent from this starship's cli. by exit code alone they are one number. a
version that dropped the subcommand would report a defect that does not exist. the output is
classified instead: an absent subcommand reports as UNAVAILABLE, never a fail.

## verify: why a caveat prints to stdout, not stderr

a `•` line returns 0 even when the parse is unchecked. stderr is a separate pipe with no
order relative to stdout. a caveat routed there floats away from the fact it qualifies —
worse than no caveat at all. a real failure still routes to stderr, to break the alignment
and draw the eye.

## .see also

- `rule.require.repo-as-source-of-truth` — what a drift from the repo means
- `gotcha.pipefail-grep-q` — why the parse-check branch avoids `grep -q`
- `howto.install-configs-from-a-worktree.md` — the `$GROVE_SRC` vs `DEV_ENV_SETUP_DIR` split
