# howto: tune nvim when it slows at scale

## .what

a plugin feels fine at 100 items and seizes at 1000. this brief is the playbook to find why and fix it, written so a reader with no nvim internals background can run it start to finish.

⇒ worked case: `<C-g>` (codediff) on a PR with 6.4k changed files froze nvim: it refreshed twice a second while idle, and each select rewrote all 7k rows. after: open 1.1s cold / 0.6s warm, select 16–36ms, zero idle refreshes (headless, real worktree, 2026-10-07). the clamp it left is `prove.codediff-refresh-stays-quiet`.

## .the one idea

> **slow = cost per call × number of calls.** measure both. never fix a guess.

each round below found a cause the round before could not see, and two first guesses were wrong. only measurements were right.

## .the playbook — run these in order

### 1. reproduce it headless, against the real config

- the driver: `rhx nvim.test.headless --probe <file.lua> --arm <name> --out .temp/<dir>`
  - it boots the shipped `init.lua`, runs your lua, and hands you `PROBE_ARM` + `PROBE_OUT`
  - your probe writes one `key=value` row per fact to `PROBE_OUT`
- build the scale TWO ways, because each finds what the other misses:
  - a **fixture**: a temp git repo with N changed files (`vim.fn.tempname()`, `git init`, write N files, commit, modify all). cheap, repeatable, good for clamps
  - the **real repo**, read-only. the fixture had 20-char paths; the real repo had 100+ char paths, and that alone hid a 1.3s cost
- 🛑 a real repo is read-only: no stage, no restore, no buffer write. set `vim.env.GIT_OPTIONAL_LOCKS = '0'` so even `git status` leaves the index alone

### 2. count calls and time them — wrap the suspects

```lua
local stats = {}
local function wrap(mod, key)
  local m = require(mod); local orig = m[key]
  m[key] = function(...)
    local t = vim.uv.hrtime()
    local r = { orig(...) }
    local s = stats[key] or { n = 0, ms = 0 }
    s.n, s.ms = s.n + 1, s.ms + (vim.uv.hrtime() - t) / 1e6
    stats[key] = s
    return unpack(r)
  end
end
```

- wrap the functions a plugin calls through its module table (`M.render`, `M.refresh`)
- a function called as a local upvalue cannot be wrapped this way — check how the caller reaches it

### 3. hold an idle window

- wait 10–20s with no input and count calls
- **any call with no input is the first suspect.** measured: 36 refreshes in 20s, zero keys pressed

### 4. profile to the line, then to the caller

- `require('jit.p').start('Fl', path)` … `stop()` → the hot lines
- `start('F4', path)` → each hot function with its 3 callers, when you need to know WHO calls it
- write the profile under `.temp/`, then open the hot line in the plugin's source (`~/.local/share/nvim/lazy/<plugin>/lua/...`)

### 4b. put the events on a timeline, with instruments OFF

- totals per function cannot tell you what the human waits on. a timeline can: stamp `t=<ms>` at each event (command start, git callback, tree build, each render, the select) and read the gaps
- 🛑 **instruments lie.** a timer wrapped around a function called 50k times, plus `jit.p` on, turned a 1.4s open into 6.2s on the same code. time the human's wait with only cheap marks on cold paths; profile in a separate run
- the timeline is what found the last hitch: a refresh ~2s after open that rebuilt 7k rows for an unchanged file list

### 5. test each hypothesis against a baseline before you act

- guessed: extmarks were slow. baseline: the same 6.5k extmark calls on a scratch buffer cost the same 54ms → wrong guess, dropped
- a subagent reported saves and focus trigger refresh. the source had no such code → corrected before it shaped a fix

### 6. fix at the cause, one shape per cause

| what the numbers showed | the fix shape | the worked instance |
|---|---|---|
| calls with no input | find what wakes it; stop the wake | `git status` took `index.lock`, the `.git/` watcher woke on it → `GIT_OPTIONAL_LOCKS=0` |
| a wrapper doubles work | restructure so work runs once | our restore ran between two renders → restore first, render once |
| every call redoes ALL rows to change two | diff: rewrite only rows that changed | a select moved one highlight and rewrote 7k rows → `render_rows` writes 2 |
| the same pure work repeats | memoize on the EXACT inputs | row builds keyed on width/expanded/selected + row content |
| a cache keyed on an object misses after a rebuild | two keys: object for speed, content for rebuilds | refresh builds new nodes for the same files |
| a cache key costs a scan per call | cheap fast-path key first | a content key per row on each select made selects SLOWER, until a per-node key went first |
| a regex cost grows with input length | rewrite it as a linear scan | `([^/]+)$` rescans from each byte → `.*/(.*)$`, or skip it |
| you cannot edit the plugin's slow line | hand it cheaper input that yields the same output, and clamp the parity | upstream row build got a basename-only view of the node; a probe compares all 696 rows against upstream, 0 mismatches |
| a refresh redoes all the work for an input that did not change | compare a signature of the input to the last one; on a match, stop after the cheap fetch | a focus-driven refresh ran git, then rebuilt and redrew 7k rows for the same file list → it now stops after git |
| the work covers every line, but the human sees ~50 | do it only for the lines on screen | 40k highlight extmarks written per render → a decoration provider paints the visible lines only (render 537ms → ~30ms) |
| a per-item copy of shared structure | share the immutable parts | each node copied its indent list; siblings now share at most two lists per level |
| a slow bridge call (`vim.fn.*`) per item | answer the common case in Lua; memoize the rest per pass | `strdisplaywidth` of printable ASCII is `#s`; other strings ask vim once per render |
| a compile repeats per item | compile once, cache it | ignore globs compiled per file → per glob |

### 7. clamp each fix, and prove the clamp bites

- a permanent probe under `.play/permanent/`, driven by a `.play.sh` that judges the rows
- one `control` arm (as shipped) plus one `old-*` arm per fix that RE-BREAKS it inside the probe
- 🛑 an `old-*` arm that reads like control means the counter cannot see the break: fix the counter
- judge stable signals (rows written, call counts), never wall-clock time — a small-N clock read is noise

## .the cues

| when… | then… |
|---|---|
| slow to open AND slow to use | idle window first |
| a fix makes one path faster and another slower | your new cache upkeep runs on the hot path. give it a fast path |
| the fixture is fast and the real repo is slow | the real data has a shape the fixture lacks: long paths, many files, deep dirs |
| a plugin watches `.git/` | `gotcha.git-status-wakes-its-own-watcher` |
| our init.lua wraps a plugin function | count how often the wrapper calls through |

## .the probe traps

| trap | fix |
|---|---|
| the probe `cd`s into its fixture, so a relative `PROBE_OUT` lands inside it | `vim.fn.fnamemodify(out, ':p')` first |
| `ENV=1 rhx …` is blocked by the permission hook | encode the knob in the arm name |
| reads under `/tmp` are blocked | write profiles under `.temp/` |
| our overrides land after a `vim.defer_fn` | wait until `debug.getinfo(fn).source` ends in `init.lua`, never on a clock |
| a wrapper counts outer calls only, so it misses a second call inside our patch | count the side effect instead (`nvim_buf_set_lines` on the target buffer) |
| a new `.play/permanent/` file will not run | `play.run` runs only what the index holds — stage it first |
| `grepsafe` cannot read plugin source outside the repo | use `Read` on the plugin file |
| a wrapper passes `unpack({...})`, and the plugin passes a nil mid-list (`base_revision`) | keep the count: `local n = select('#', ...)` then `unpack(args, 1, n)` — else the call breaks with no visible error |
| a mark inside a git callback calls `vim.fn.writefile` | that callback runs in a libuv fast event, where `vim.fn` throws and kills the plugin's own callback. `if vim.in_fast_event() then vim.schedule(...)` |
| the probe ends with a thin page and no error | `pcall` the command and write the error as a row; a swallowed error reads like a hang |
| a fix needs a fair before/after, and an old config copied out of `~/.config/nvim` will not boot (`E492: Not an editor command`) | measure before you change, and keep the rows |

## .see also

- `howto.diagnose-nvim-hang` — runaway CPU or memory, rather than a slowdown at scale
- `gotcha.git-status-wakes-its-own-watcher` — the loop this playbook found
- `.play/permanent/prove.codediff-refresh-stays-quiet.play.sh` — the clamp, and a template for the next one
