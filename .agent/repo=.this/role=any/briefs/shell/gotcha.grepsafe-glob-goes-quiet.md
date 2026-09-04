# gotcha: grepsafe's `--glob` can answer 0 on a file that MATCHES

## .what

`rhx grepsafe --pattern <p> --glob <one-file-path>` reported **0 matches** on a file that
holds four. the same pattern, read by any other tool, finds them.

measured 2026-08-06:

```
rhx grepsafe --pattern 'configure_robot_brains|install_env' \
  --glob '.agent/repo=.this/role=any/briefs/desktop/system/howto.silence-claude-cli-nags.md'
   └─ matches: 0

# the same file, same pattern, read directly:
   19: … settings.json `env` (`configure_robot_brains`) |
   34: // ~/.claude/settings.json — written by configure_robot_brains
   77: … is written by `configure_robot_brains`, but it only works on …
  117: sync.devenv.brains   # run configure_robot_brains …
```

## .the cause — measured 2026-09-03, by a dump of the built argv

**any glob that holds a `/` matches no file, under the `grep` fallback.** a glob with no
`/` works. that one sentence covers every sample in this file.

it is a chain of two, and each half is a trap this repo already names:

1. **the engine is chosen silently, and the wrong one wins.** `grepsafe.sh` picks with
   `command -v rg`. `rg` on this box exists ONLY as an interactive zsh alias into
   claude-code's vendored binary, so a `bash` procedure cannot see it
   (`gotcha.a-tool-found-by-path-answers-only-a-human`). it takes the `grep` fallback and
   says no word about which engine ran.
2. **the two engines disagree on what the glob means.** `rg --glob` matches the **path**;
   GNU `grep --include` matches the **basename**, only. so `.agent/**/*.md` can never
   match a basename, and grep reports zero.

```
[grep] [-rl] [--exclude-dir=.git] [--include=.agent/**/*.md] [-E] [the bar was MET] [<abs>]
```

⚠️ **the earlier diagnosis here was WRONG, and it read as sound for a month.** it said
*"`--glob` takes a PATTERN, never a path"* — fitted to two samples that were both bare file
paths. it does not explain `--glob '**/*.md'`, which is a pattern, has wildcards, and still
returns 0. the true cause subsumes all four.

⇒ this is this file's own warning, turned on itself: **a diagnosis from one sample names
whatever was unusual about that sample.** both samples were paths, so "path" got written
down; the `/` they shared went unnamed.

⇒ and the reason it survived a month is that a workaround-brief **removes the pressure to
open the tool**. a documented trap reads as handled. only a repair forces the read that
corrects the diagnosis — dispatched as `rhachet-roles-ehmpathy#620`.

### ⚠️ .the `=` in the path is NOT the cause — measured 2026-08-14

`repo=.this` and `role=any` are the visible oddity of the first sample, and a diagnosis that
names them is too narrow. the same `0` comes back on a path with no `=` anywhere in it:

```
rhx grepsafe --pattern '100|floor|too few|n_scope' \
  --glob '.play/temporary/prove.early-exit-readers-are-safe.play.sh'
   └─ matches: 0

rhx grepsafe --pattern 'direction 0' --glob <same path> --context 30
   └─ matches: 0

# the file, read directly:
  257:  if [[ "$n_scope" -lt 100 ]]; then
```

both patterns are present, on one line, and `--glob` saw neither. ⇒ the trigger is not a
character class in the path, so a reader sent after one hunts a cause with no part in it.

⚠️ **a diagnosis from one sample names whatever was unusual about that sample.** the first
measurement had two unusual properties — an `=` in the path, and a bare path where a
pattern belongs — and the visible one is the one that gets written down.

## ⚠️ .why this one is dangerous rather than a mere irritation

**an absent match and an unasked question print the same line.** `matches: 0` is exactly
what a clean file looks like, so the failure mode is a FALSE ✔ — the shape
`rule.forbid.failhide` exists to catch.

it bit in the session it was found: a brief was checked for stale paths, grepsafe answered
`0`, and that read as "clean" on a file that held four stale references. a second tool caught
it.

⚠️ and it had been trusted once already that day. an earlier `--glob 'src/**/*.sh'` search
for `DISABLE_AUTOUPDATER` also answered `0` — and that one was TRUE, since the string lives
in `src/grove.provision/**` and `src/**/*.sh` is a narrower net than it looks. two identical
answers, one true and one false, with no way to tell them apart from the output.

### ⚠️ .the second direction of harm — it degrades what is already RIGHT

measured 2026-08-14. a brief credited a play with a `<100`-file scope floor, and the claim
was **true** (`:257`). grepsafe answered `0`, which read as *"you asserted a feature that
does not exist"* — and the next move, one keystroke away, was to soften a correct sentence
into a vaguer one.

so a false `0` does not merely let a defect through. pointed at a **verification** step it
argues that a real guarantee is absent, and the repair it invites is to **delete the claim to
that guarantee** — which leaves the guarantee unrecorded and the next reader unaware it is
there to rely on.

⇒ **when a tool's silence would make you WEAKEN something, that is the moment to read the
file.** an absence that costs a deletion deserves the same second read as one that costs a
✔.

## .the tell

if a grepsafe search over a `--glob` returns `0`, ask whether the glob could match **any**
path — not whether the pattern could match any line.

a cheap disproof: drop `--glob` and search the whole repo. if the string appears there and
not under the glob, the glob is the problem.

## .what to do instead

- for ONE known file, read it — a `Read` proves both presence and absence
- for a directory, prefer a glob with no `=` in the path segments, or drop `--glob` and
  filter the output
- never treat a `0` under `--glob` as proof of absence without a second read

## .see also

- `rule.forbid.failhide` — a check that cannot speak must not print a clean line
- `gotcha.grepsafe-ignores-stdin.md` — the other grepsafe surprise
- `rule.require.trust-but-verify` — a tool's answer is a claim like any other
- `gotcha.a-check-that-cries-wolf-gets-silenced.md` — the opposite failure, same cost
