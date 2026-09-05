# gotcha.grepsafe-ignores-stdin

## .what

`rhx grepsafe` searches files under `--path` (default `.`). it does **not** read stdin. so a
pipe into it is silently discarded, and what you get back is a grep of the whole working
tree:

```sh
# 👎 the pipe is dropped; this greps the ENTIRE repo
git show origin/main:src/bundle.upgrade.sh | rhx grepsafe --pattern 'clone|git@'
```

## .why it is worth a brief

it does not error. it exits 0, prints a tree of file:line hits, and every one of them is
real — just not from the file you asked about. the output is **shaped like an answer**, which
is what makes it dangerous: it invites a citation that looks measured and is not.

that is the same defect class this repo's verifies exist to catch. a check that cannot fail,
or that answers a different question than the one asked, is worse than an absent check —
because a reader trusts it and stops looking (`rule.require.trust-but-verify`,
`gotcha.a-check-that-cries-wolf-gets-silenced`).

### measurement — 2026-07-31

a query meant to read one **298-line** blob returned **121,761 lines / 269MB**. the size
was the only tell; the content looked plausible throughout.

## .how to read a git blob instead

the blob is not on disk, so `grepsafe --path` has no file to point at. read it directly:

```sh
# 👍 the whole file, when it is small
git show origin/main:src/devenv.env.sh

# 👍 a window, when it is not — measure first, then slice
git show origin/main:src/bundle.upgrade.sh | wc -l
git show origin/main:src/bundle.upgrade.sh | head -n 120
git show origin/main:src/bundle.upgrade.sh | tail -n 40
```

`head`, `tail`, and `wc` all read stdin, so they compose with `git show` the way grepsafe
does not. to search rather than read, check the file out first and give `grepsafe` a real
path.

## .the tell

if a `grepsafe` line count is wildly larger than the file you meant to search, the pipe was
ignored. treat the result as void, not as a wide match.

## .see also

- `gotcha.pipefail-grep-q` — the other pipe-shaped trap, where `grep -q` SIGPIPEs its producer
- `rule.require.trust-but-verify` — a plausible-looking output is not a measurement
