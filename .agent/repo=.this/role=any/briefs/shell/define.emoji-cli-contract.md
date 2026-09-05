# define.emoji-cli-contract

## .what

the emoji cli has three parts with three different invocation models. the
split is deliberate and load-bear.

**three implementation files. everything else points at them.**

| file | kind | reached by |
|------|------|-----------|
| `src/emoji.zsh` | **implementation** — widget + `emoji` cmd | sourced by `~/.zshrc` |
| `src/emoji.index.build.sh` | **implementation** — the index transform | `2.9.emoji`'s provision phases |
| `src/emoji.test.zsh` | **tests** — collocated with what it tests | `2.9.emoji`'s configure verify |
| `.agent/…/skills/emoji.get.sh` | sources the widget, calls `_emoji_lookup` | `rhx emoji.get` |

everything real lives in `src/`, per `rule.require.repo-as-source-of-truth`.
`.agent/…/skills/` holds one thin READ surface and no second copy of anything.

**the test is collocated**, per the ehmpathy convention
(`howto.write.[lesson]`). that also shortens the path it resolves:
`${0:A:h}/emoji.zsh` rather than four `../` hops.

### 🛑 .why there is no `emoji.index.set` skill, and no `emoji.test` skill

neither survives this repo's rules:

| skill | why it is absent |
|-------|------------------|
| `emoji.index.set` | the index is MACHINE STATE. a skill that built it would be a second entrypoint that drives grove state — `rule.require.grove-provision-as-the-only-entrypoint` names that a blocker, and `rule.forbid.repair-plays` already deleted a pure forwarder for being one by the letter of the rule |
| `emoji.test` | ⚠️ measured 2026-08-14: **rhachet discovers `.sh` only.** a `.agent/…/skills/emoji.test.zsh` symlink answered `no skill "emoji.test" found`, while `emoji.get.sh` — created in the same directory in the same minute — was found at once. so the symlink was a pointer no tool could reach |

⇒ the one command that builds the index is
`grove.provision --what 2.9.emoji --mode apply`, and the suite is run by that
bundle's configure verify (or by hand, `zsh src/emoji.test.zsh`).

⚠️ `emoji.get` is exempt from the first row because it only **reads** the
index. it converges no state, so it is not an entrypoint.

### ⚠️ zero copies, on purpose

four near-misses, all corrected — do not re-introduce them:

| was | why it was wrong | now |
|-----|------------------|-----|
| the ranks restated in `emoji.get` | TAB and the command could answer the same query differently | sources `_emoji_lookup` |
| a 43-line wrapper for the builder | it stripped `--repo/--role/--skill`, which the builder **already** strips | the bundle calls the builder directly |
| the pins restated in `diagnose.emoji-index-sources` | a bump in the bundle would leave the play to report drift against a version the tree no longer fetches | the play greps them out of the bundle |
| scratch copies in a `.temp/` proto dir | they froze before the FE0F fix and before gestures 2–3 — a stale build there yields a third fewer emoji and no ❤️ | deleted |

the last is the instructive one: a scratch copy is not inert. it keeps
working, silently, at whatever correctness it had the day it was forked.

## .why the widget is sourced, never `rhx`

measured: `rhx globsafe` costs **638 ms** end to end. that is node boot, and
it is paid per invocation.

| path | cost | verdict |
|------|------|---------|
| in-shell awk over the index | ~9–16 ms | fits |
| through `rhx` | ~638 ms | 6x past the ~100 ms perceptual limit |

a TAB press cannot pay 638 ms. so the hot path is a sourced zsh function, and
`emoji.get` exists as a headless test surface only.

⚠️ **do not "unify" these by a route through rhx.** that route reads tidier
and breaks the one constraint the whole design rests on.

---

## .the data contract

`$XDG_DATA_HOME/emoji/emoji.tsv`, default `~/.local/share/emoji/emoji.tsv`.
override with `$EMOJI_INDEX`.

three tab-separated columns, no header:

```
char <TAB> name <TAB> keywords
🚀	rocket	launch rocket rockets space travel
```

| col | content | source |
|-----|---------|--------|
| 1 | the emoji, **fully-qualified** | emoji-test.txt |
| 2 | primary name | CLDR `.tts[0]` |
| 3 | keywords, space separated | CLDR `.default` |

flat on purpose: greppable, diffable, hand-fixable, and parseable by one awk
with no interpreter boot.

⚠️ **no row count is written here.** the file is DERIVED, so its size moves with
every pin bump and no check reddens when a written count goes stale
(`repo.overview.md`, `.the shape`). ask the artifact instead:

```sh
wc -l ~/.local/share/emoji/emoji.tsv
```

### the two sources, and their pins

| source | role |
|--------|------|
| `cldr-json` → `cldr-annotations-full/annotations/en/annotations.json` | names + keywords |
| `unicode.org/Public/emoji/<ver>/emoji-test.txt` | **defines** what is an emoji |

CLDR annotates *characters*, not emoji — `:` and five invisible skin-tone
modifiers among them. the intersect against emoji-test.txt is what makes the
index safe, and it is what stops `:colon`+TAB from insertion of the very
trigger char you just typed.

🛑 **both are pinned to a VERSION and sha256-verified.** never fetch
`cldr-json/main/…` or `emoji/latest/…`: each is a ref that MOVES, so neither can
carry a hash, and the fetch satisfies neither `rule.require.verify-binary-downloads`
nor `prove.every-fetch-is-verified`.

⚠️ the drift is not theoretical. measured 2026-08-14:

> `emoji/latest/emoji-test.txt` serves bytes stamped `# Version: 17.0`, and
> `emoji/17.0/emoji-test.txt` answers **404**. so the bytes `latest` serves
> today CANNOT BE PINNED AT ALL — unicode has not published that version's own
> directory.

16.0 is the newest version with a stable versioned path, so it is the pin.

both pins are **TIER 2**: neither vendor publishes a checksum beside these
files, so each hash pins WHICH BYTES WE SAW rather than a value upstream
vouches for. `prove.sha256-pins-bite` carries that distinction per pin
(`term=pin`). what makes it sufficient: both are DATA, distilled by a
transform that verifies its own output, and no byte of either is executed.

to read the drift, and learn whether a bump is available, fetch each pinned source
and compare its live sha256 against the pin recorded here — a
`diagnose.emoji-index-sources` probe asks exactly that.

---

## .the rank contract

**one implementation, in `src/emoji.zsh` as `_emoji_lookup`.** `emoji.get`
sources that file and calls it; the ranks are not restated anywhere.

⚠️ **a second copy plus "keep them in sync" is not a fix.** drift would mean TAB
and the command answer one query two ways — the worst surprise this tool can
produce. what makes one copy possible: the widget's `zle`/`bindkey` block is
guarded on `[[ -o interactive ]]`, so a non-interactive caller may source the file.

| rank | match | example |
|------|-------|---------|
| 1 | exact name | `rocket` → 🚀 |
| 2 | exact keyword | `happy` → 😀 |
| 3 | name prefix | `turt` → 🐢 |
| 4 | keyword prefix | `boom` → 💥 |
| 5 | partial anywhere | |

ties break by CLDR order, which is roughly canonical-first. **prefix ahead of
partial is a decision, not an accident** — it is what makes short queries land
on the obvious emoji.

### two implementation constraints

**no regex on the query.** only `index()` and `substr()`. a query of `c++` or
`(` must not be a syntax error or a catastrophic backtrack. verified: `c++`
returns a clean "no emoji" rather than a crash.

**one awk process.** the obvious shape is `awk | sort -k1 | cut`, and it
measured **48.2 ms**. awk buckets by rank and emits in order at `END` instead:
**15.7 ms**, same output, stable within a rank. this runs per keystroke, so
the fork count matters.

---

## .the three gestures

| gesture | key | behavior |
|---------|-----|----------|
| 1 | `:turt` + **TAB** | unique hit inserts silently; multiple opens fzf |
| 2 | `:zap` + **`:`** | the SECOND colon commits — takes the top rank, no picker |
| 3 | `:zap` + **Enter** | rewrites the buffer to `emoji zap`, then accepts |

all three share the same anchor (below) and the same rank order (above).

**gesture 2 is decisive on purpose.** the second colon means the human
committed to a name, so it takes rank 1 rather than opens a picker. TAB
remains the gesture for "show me the options".

**gesture 3 rewrites rather than intercepts.** the buffer becomes the literal
`emoji zap` before accept, so history records a real, re-runnable command
instead of a shape only this widget understands.

### what each gesture falls back to

| gesture | on no match |
|---------|-------------|
| TAB | `zle $_EMOJI_PRIOR_TAB` — normal completion |
| `:` | `zle self-insert` — a literal colon |
| Enter | buffer untouched, `zle $_EMOJI_PRIOR_ACCEPT` — runs as typed |

⚠️ the fall-back must go **through zle**, not be written by the widget. the
test asserts on the zle target for exactly this reason: a literal colon that
the widget wrote itself would look identical on screen while it bypassed
every other `:` binding in the shell.

---

## .the trigger contract

all three gestures fire only when the word under the cursor **matches**:

```
^:[a-zA-Z0-9_+-]+$
```

**match, not contains.** the word must *begin* with the colon.

that distinction is the whole safety argument. measured against 20,499 real
commands in `~/.zsh_history`:

| probe | matches |
|-------|---------|
| lines with a colon before a letter | 66 (0.32%) |
| **words that begin with a bare colon** | **0** |

all 66 keep their colon mid-word:

```
npm run provision:integration-test-db
git@github.com:ehmpathy/sdk-config.git
scp host:path
```

⚠️ **relax `match` to `contains` and all 66 become live collisions.** if you
ever touch that regex, re-run the history count.

two more cases the anchor covers, both verified in the test suite:

| input | why it is safe |
|-------|----------------|
| `::` | the pattern needs 1+ chars after the colon |
| `:qa!` | `!` is outside the charset — and this is real, 8 such vim-reflex typos live in the history |

**pastes are safe by construction.** zsh routes pasted text through
`bracketed-paste`, not `self-insert`, so a pasted `arn:aws:s3` never reaches
the `:` widget at all.

### fall-through

on zero emoji matches, the widget calls the widget TAB was bound to *before*
it — captured at source time, never a guessed default:

```zsh
_EMOJI_PRIOR_TAB=$(bindkey '^I' | awk '{print $2}')
```

guarded so a re-source cannot capture `_emoji_tab` itself and self-loop.
the cost of a false trigger is therefore exactly one normal tab.

---

## .the command contract

```sh
emoji                  # fzf over the index -> stdout + clipboard
emoji <query>          # best match -> stdout, pipe-safe
emoji <query> --pick   # force the picker even on a unique hit
```

on a unique hit: **silent insert**, no confirm. the action is reversible by one
backspace, and a confirm prompt is precisely the detour the tool exists to
remove.

stdout carries the emoji alone. the final newline appears only when stdout
is a tty, so `$(emoji rocket)` stays clean.

### exit codes

| code | meaning |
|------|---------|
| 0 | found |
| 1 | picker cancelled |
| 2 | constraint — no match, absent index, bad arg |

---

## .hazards discovered in the build

four hazards surfaced during the index and widget build: the FE0F drop, a
`trap '' PIPE` footgun, rhx as a non-pipe surface, and a backtick inside a
double-quoted message. see
`define.emoji-cli-contract.demo=build-hazards.md`.

---

## .verification

the transform runs its own checks before it installs a new index, and
`2.9.emoji`'s provision verify re-runs them against the live file — so a bad
index fails loud rather than ships:

| assertion | guards against |
|-----------|----------------|
| `:` absent | `:colon`+TAB would insert the trigger char itself |
| `,` `{` absent | ascii punctuation is not emoji |
| `🏻` absent | bare skin-tone modifiers render as an empty cell — reads as silent failure |
| `❤️` `⚠️` present | the FE0F strip step regressed |
| `happy turtle launch tada lit boom stop wave heart warning` all find an emoji | the keyword promise of the wish |

the builder writes via temp + `mv`, so a failed build never truncates a good
index.

check a live index by hand:

```sh
bash src/emoji.index.build.sh --check ~/.local/share/emoji/emoji.tsv
```

---

## .install — the bundle

`src/grove.provision/2.shell/2.9.emoji/`, dispatched last in its section.

```sh
grove.provision --what 2.9.emoji --mode apply
```

it is **two halves, and they are two PHASES rather than one** because they
fail for different reasons and are fixed by different moves:

| phase pair | artifact | reaches the wire? |
|------------|----------|-------------------|
| provision | `~/.local/share/emoji/emoji.tsv` + its `.pins` stamp | yes, at two pinned urls |
| configure | `~/.zshrc.emoji.sh`, a copy of `src/emoji.zsh` | never |

**it proves itself.** the configure verify runs the 20-case suite and fails the
phase if any gesture regressed — a bundle that rebinds TAB should not claim
success without evidence that TAB still works
(`rule.require.upgrade-entries-verify-themselves`).

**it asserts `jq` rather than re-installs it.** jq comes from `2.1.toolkit`,
which runs first in this section. a second `pkg_install` here would be a second
declaration of that dependency, and on a seat with no root it would fail over a
package that is already present.

⚠️ **fzf is NOT asserted**, though the picker needs it. `2.1.toolkit` treats fzf
as best-effort and 🌙s where a box's repos lack it, so a hard require here would
fail this bundle over a dependency its own owner declined to guarantee. the
picker degrades; the TAB/`:`/Enter gestures do not need it.

### 🌙 it DECLINES on a box with no human

every gesture is a KEYSTROKE — TAB, `:` and Enter, read by zle. an agent that
drives a grove sends whole command strings down a duct and presses no key, so
on a grove this bundle would fetch ~1 MB, distill an index, and serve a widget
nobody can trigger.

⇒ that is a preference, not a fact about the machine — the same reasoning
`6.apps` applies (`define.6-apps-is-laptop-only`). the decline lives at the
bundle, since `2.shell`'s other seven children all DO apply to a headless box
(`rule.require.identical-bundle-composition`).

⚠️ the decline's indent is **computed**, never a literal run of spaces. it
prints from the bundle's own dispatch rather than from a phase, so
`bundle.upgrade`'s pipe pad never touches it, and a hardcoded indent reads
correctly at exactly one depth.

### 🛑 the decline does NOT hide the fetch from every check

`.the DARKEST corner` of `define.provision-defect-shapes` is exactly this
shape: a path that runs on one box class, once, on a fresh machine. the remedy
it names is a play that reaches the SOURCE from any box — and both pins here
are discovered from the tree by `prove.sha256-pins-bite`, which runs on a grove
that will never install a single emoji.

### a re-apply reaches the wire ZERO times

`~/.local/share/emoji/emoji.pins` records which pins the index was derived
from. a run whose declared pins match the stamp has no work to do; bump either
and the stamp disagrees, so the next apply rebuilds
(`rule.require.idempotent-install-procedures`).

⚠️ the upsert tests the **index AND the stamp**. a stamp with no index beside it
is what a half-finished run leaves, and a check on the stamp alone would report
converged over an absent index — which the widget then reports as a fault at
every shell start, with no run left to fix it.

### ⚠️ it must not live in `~/.bash_aliases`

that is the obvious home for shell additions in this repo, and it is wrong
here. `src/zshrc.sh` exports `BASH_ENV=~/.bash_aliases`, so **bash** sources
that file for every non-interactive shell. the widget calls `zle` and
`bindkey`, which bash has none of — every command, git alias, and makefile
would emit errors.

so it is a separate `~/.zshrc.emoji.sh`, sourced from zshrc only, behind a
`-f` guard. ⚠️ that guard is load-bear rather than defensive habit: this bundle
declines on a headless box, so a grove holds no such file.

### ⚠️ load order is load-bear

it sources **after** compinit and **after** the fzf keybindings, inside the
interactive block:

- after `compinit` — it wraps a completion widget
- after fzf's `key-bindings.zsh` — so our TAB bind takes precedence

this is the same order discipline the up/down binds already document in
`src/zshrc.sh` ("after fzf so these take precedence").

## .see also

- `src/emoji.zsh` — the widget, and the one home of the rank logic
- `src/emoji.test.zsh` — the 20 gesture + safety cases
- `src/emoji.index.build.sh` — the transform, and why it reaches no network
- `define.emoji-cli-contract.demo=build-hazards.md` — the four hazards found in the build
- `rule.forbid.surprises` — why the index filter is a correctness matter, not polish
- `rule.require.grove-provision-as-the-only-entrypoint` — why no `emoji.index.set` exists
