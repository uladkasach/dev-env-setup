# define.emoji-cli-contract

## .what

the emoji cli has three parts with three different invocation models. the
split is deliberate and load-bearing.

**two implementation files. everything else points at them.**

| file | kind | invoked as |
|------|------|-----------|
| `src/emoji.zsh` | **implementation** — widget + `emoji` cmd | sourced by zshrc |
| `src/emoji.index.build.sh` | **implementation** — index builder | `install_emoji` |
| `src/emoji.test.zsh` | **tests** — collocated with what it tests | `zsh src/emoji.test.zsh` |
| `.agent/…/skills/emoji.index.set.sh` | **symlink** → the builder | `rhx emoji.index.set` |
| `.agent/…/skills/emoji.test.zsh` | **symlink** → the tests | `rhx emoji.test` |
| `.agent/…/skills/emoji.get.sh` | sources the widget, calls `_emoji_lookup` | `rhx emoji.get` |

everything real lives in `src/`, per `rule.require.repo-as-source-of-truth`.
`.agent/…/skills/` holds only symlinks and the one thin test surface, so an
agent can reach them by `rhx` without a second copy.

**the test is collocated**, per the ehmpathy convention
(`howto.write.[lesson]`: "add .integration.test.ts file (collocated)"). the
first draft put it under `.agent/…/skills/` — which matched this repo's
incidental habit (`termwork.test.sh`, `nvim.test.headless.sh`) but not the
stated rule. collocation also simplifies the path it resolves: `${0:A:h}/emoji.zsh`
rather than four `../` hops. `:A` resolves symlinks, so the `rhx` entry still
lands in `src/`.

### ⚠️ zero copies, on purpose

three near-misses, all corrected:

| was | why it was wrong | now |
|-----|------------------|-----|
| the ranks restated in `emoji.get` | TAB and the command could answer the same query differently | sources `_emoji_lookup` |
| a 43-line wrapper for the builder | it stripped `--repo/--role/--skill`, which the builder **already** strips | a symlink |
| scratch copies in `.temp/emoji-proto/` | they froze before the FE0F fix and before gestures 2–3 — a stale build there yields 933 emoji with no ❤️ | deleted |

the third is the instructive one: a scratch copy is not inert. it keeps
working, silently, at whatever correctness it had the day it was forked.

## .why the widget is sourced, never `rhx`

measured: `rhx globsafe` costs **638 ms** end to end. that is node boot, and
it is paid per invocation.

| path | cost | verdict |
|------|------|---------|
| in-shell awk over the index | ~9–16 ms | fits |
| through `rhx` | ~638 ms | 6x past the ~100 ms perceptual limit |

a TAB press cannot pay 638 ms. so the hot path is a sourced zsh function and
the rhx skills exist for build and test only.

⚠️ **do not "unify" these by routing the widget through rhx.** it would read
as tidier and would break the one constraint the whole design rests on.

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

1,588 rows, ~96 KB. flat on purpose: greppable, diffable, hand-fixable, and
parseable by one awk with no interpreter boot.

### the two sources

| source | role |
|--------|------|
| `cldr-annotations-full/annotations/en/annotations.json` | names + keywords |
| `unicode.org/Public/emoji/latest/emoji-test.txt` | **defines** what is an emoji |

CLDR annotates *characters*, not emoji — 1,966 entries of which only 1,588
are emoji. the intersect against emoji-test.txt is what makes the index safe.

---

## .the rank contract

**one implementation, in `src/emoji.zsh` as `_emoji_lookup`.** `emoji.get`
sources that file and calls it; the ranks are not restated anywhere.

⚠️ an earlier draft copied the rank logic into `emoji.get` and this brief said
"they must stay in sync". that is a duplicate with a note attached, not a fix —
drift would mean TAB and the command give different answers to the same query,
which is the worst surprise this tool could produce. the fix was to guard the
widget's `zle`/`bindkey` block on `[[ -o interactive ]]`, which makes the file
safe to source from a non-interactive caller.

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
| 2 | `:zap` + **`:`** | the second colon commits — takes the top rank, no picker |
| 3 | `:zap` + **Enter** | rewrites the buffer to `emoji zap`, then accepts |

all three share the same anchor (below) and the same rank order (above).

**gesture 2 is decisive on purpose.** the closing colon means the human
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
"arn:aws:s3:::'$BUCKET_NAME'"
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

stdout carries the emoji alone. the trailing newline appears only when stdout
is a tty, so `$(emoji rocket)` stays clean.

### exit codes

| code | meaning |
|------|---------|
| 0 | found |
| 1 | picker cancelled |
| 2 | constraint — no match, absent index, bad arg |

---

## .hazards discovered in the build

### 1. the FE0F trap — cost 655 emoji including ❤️ and ⚠️

CLDR keys `❤` as `2764`. emoji-test.txt lists the fully-qualified `2764 FE0F`.
U+FE0F is the variation selector that promotes a legacy dingbat to a color
emoji — invisible, and absent from the CLDR key.

a byte-equality intersect therefore drops **every** such pair:

| filter | kept |
|--------|------|
| naive byte match | 933 |
| FE0F stripped on both sides | **1,588** |

so: match on the stripped form, **emit the qualified form**. emit the bare
`U+2764` and it renders monochrome text-style, which is not what anyone means
by the heart emoji.

`❤️` and `⚠️` are canaries in the verify set. if they vanish, this regressed.

### 2. `trap '' PIPE` causes the error it means to prevent

- `trap '' PIPE` → signal **ignored**, so `write()` returns EPIPE and printf
  prints `write error: Broken pipe`
- no trap → default action, exit 141, which the rhx harness flags
- `trap 'exit 0' PIPE` → **handled**, quiet ✅

ignore is not the same as handle.

### 3. `rhx` is not a measurement or pipe surface

`rhx emoji.get --query rocket | wc -l` returns **4** for a one-emoji output —
the banner is on stdout. never pipe rhx output, never benchmark through it.
see `project_rhx-not-pipe-safe` in memory.

---

## .verification

`rhx emoji.index.set --check` asserts, and the builder runs the same checks
before it installs a new index — a bad index fails loud rather than ships:

| assertion | guards against |
|-----------|----------------|
| `:` absent | `:colon`+TAB would insert the trigger char itself |
| `,` `{` absent | ascii punctuation is not emoji |
| `🏻` absent | bare skin-tone modifiers render as an empty cell — reads as silent failure |
| `❤️` `⚠️` present | the FE0F strip step regressed |
| `happy turtle launch tada lit boom stop wave heart warning` all find an emoji | the keyword promise of the wish |

the builder writes via temp + `mv`, so a failed build never truncates a good
index.

---

## .install

`install_emoji` in `src/install_env.pt2.shell.sh`, invoked from
`install_env._.sh` right after `install_cli_deps` (which brings fzf + jq).

it writes two artifacts:

| artifact | from |
|----------|------|
| `~/.zshrc.emoji.sh` | `src/emoji.zsh` |
| `~/.local/share/emoji/emoji.tsv` | built by `src/emoji.index.build.sh` |

and `src/zshrc.sh` sources the first, guarded by an existence check.

**it proves itself.** `install_emoji` runs `src/emoji.test.zsh` at the end and
returns nonzero if any of the 20 cases fail — an install that rebinds TAB
should not claim success without evidence that TAB still works.

**it asserts its deps rather than re-installs them.** fzf and jq come from
`install_cli_deps`, which `install_env._.sh` orders immediately before. an
`apt install` here would duplicate that fn *and* prompt for a sudo password
mid-install for packages already present.

### day-to-day updates

`sync.devenv.emoji`, folded into `sync.devenv` alongside the other 13.
the widget copy is cheap so it syncs every run; the index is a ~1 MB network
fetch, so it builds only when absent. rebuild on demand with
`rhx emoji.index.set` — unicode ships new emoji yearly.

### ⚠️ it must not live in `~/.bash_aliases`

that is the obvious home for shell additions in this repo, and it is wrong
here. `zshrc.sh:117` sets `export BASH_ENV=~/.bash_aliases`, so **bash**
sources that file for every non-interactive shell. the widget calls `zle`
and `bindkey`, which bash has none of — every script, git alias, and
makefile would emit errors.

so it is a separate `~/.zshrc.emoji.sh`, sourced from zshrc only.

### ⚠️ load order is load-bearing

it sources **after** compinit and **after** the fzf keybindings, inside the
interactive block:

- after `compinit` — it wraps a completion widget
- after fzf's `key-bindings.zsh` — so our TAB bind takes precedence

this is the same ordering discipline the up/down binds already document at
`zshrc.sh:103` ("after fzf so these take precedence").

### verify an install

```sh
rhx emoji.index.set --check    # index is sound
zsh src/emoji.test.zsh         # 20 gesture + safety cases
```

## .see also

- `.behavior/v2026_08_02.emoji-cli/1.vision.yield.md` — the vision and its four self-reviews
- `project_rhx-not-pipe-safe` (memory) — why rhx cannot be piped or timed
- `rule.forbid.surprises` — why the index filter is a correctness matter, not polish
