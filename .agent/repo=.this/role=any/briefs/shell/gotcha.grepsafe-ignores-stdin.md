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

## 🛑 .how to SEARCH a skill's stdout instead — land it, then point at it

the section above covers a git blob. the shape that bites more often is a **skill's stdout**,
because a skill's output is exactly what a reader most wants to narrow:

```sh
# 👎 the pipe is dropped; this greps the repo and finds the WORD in briefs
rhx keyrack list --owner ehmpath | rhx grepsafe --pattern 'BEAVER' --context 5
```

⚠️ **this shape is worse than the git-blob one, and the size tell does not catch it.** a repo
grep for a domain word returns a plausible handful of rows from the very briefs that discuss
the subject — so the output is short, on-topic, and wrong. the 2026-07-31 measurement was
caught by a 269MB line count; a word like `BEAVER` produces no such signal.

⇒ land the output first, then give `grepsafe` the real path:

```sh
# 👍 one hop through a file, and the search reads what the skill actually said
rhx keyrack list --owner ehmpath | rhx teesafe --into .temp/rack.list.txt
rhx grepsafe --pattern 'BEAVER|vault|mech' --path .temp/rack.list.txt
```

`.temp/` is gitignored, so the landed copy leaves no tracked artifact. ⚠️ read what you land:
a rack `list` prints slugs, mechs, and vaults and no secret VALUES — a skill that would emit a
token must never be teed, even into a gitignored path.

🟡 `head` / `tail` / `wc` still compose directly, so reach for those where a window is enough
and no pattern is needed.

## .the tell

if a `grepsafe` line count is wildly larger than the file you meant to search, the pipe was
ignored. treat the result as void, not as a wide match.

## .see also

- `.dream/2026_09_29.grepsafe-discards-a-pipe-in-silence-rather-than-refuse-it.dream.md` — the
  upstream cure: a four-line refusal, and why a refusal beats a stdin read
- `gotcha.pipefail-grep-q` — the other pipe-shaped trap, where `grep -q` SIGPIPEs its producer
- `rule.require.trust-but-verify` — a plausible-looking output is not a measurement
