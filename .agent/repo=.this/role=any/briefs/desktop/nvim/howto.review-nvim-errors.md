# howto.review-nvim-errors

## .what

every nvim instance on this machine streams the errors it throws into **one global log**,
and `rhx nvim.errors.review` reads that log back ranked by how often each error hit.

this brief says where the log lives, when to read it, and what to do with what you find.

## .where — one global log, not per-tree

```
~/.local/state/nvim/errors.log     # the log (stdpath('state'))
~/.local/state/nvim/errors.log.1   # the previous 2MB, rotated
```

it is **global on purpose**. every nvim, in every worktree, writes to this one file — so a
flake that only shows up in one repo is still visible beside every other instance. that is
what makes cross-tree diagnosis possible: you see that the same `neominimap` fault fires in
four trees, not that it "happened once, somewhere".

it is **not** in `/tmp` — `/tmp` is wiped on reboot, and the errors most worth a fix are the
ones that recur across reboots.

each line carries the tree it came from, so you never lose the locality the global file
merges away:

```
2026-08-06T14:22:07 pid=15968 src=messages n=3 cwd=/home/vlad/git/more/dev-env-setup | Error in coroutine: ...
```

| field | reads as |
|-------|----------|
| `pid` | which nvim core instance — group by it to see one session's story |
| `src` | `messages` (runtime threw it), `notify.error` / `notify.warn` (a plugin reported it), `tally` (final count at exit) |
| `n` | cumulative hits of this signature **within that pid** |
| `cwd` | the tree it fired in — this is the cross-tree attribution |

## .why the log exists

an error scrolls off the screen and dies with the session. that means the flake you saw an
hour ago is unreviewable now, and the one you remember most is the one you fix — which is
rarely the one that costs you the most.

the log inverts that: it ranks by **frequency**, so the repair you reach for is the loudest
offender, not the most recently remembered one.

it also catches the class of error you cannot see. an error thrown from a libuv timer or a
decoration provider never reaches `vim.notify`; it lands only in `:messages`, often behind a
frozen ui. the scribe polls the message history every 5s precisely to catch that class.

## .when to review

| trigger | read |
|---------|------|
| nvim froze, or a keymap went dead | `--tail 30` — the freshest incident, raw |
| periodic hygiene (say, weekly) | default rank — what has cost you the most all week |
| after a plugin upgrade | `--since 7d` — did the upgrade add a new fault |
| you suspect one plugin | `--grep neominimap` — isolate the culprit |
| a fault seems to predate the current log | `--all` — include the rotated file |

## .how to read the rank

```sh
rhx nvim.errors.review                # top 15 by hit count
rhx nvim.errors.review --top 40       # widen
rhx nvim.errors.review --since 7d     # recent only
rhx nvim.errors.review --tail 30      # raw, newest last
rhx nvim.errors.review --grep image   # one culprit
```

the rank groups by **signature**, not exact text: every number is collapsed to `#`, so
`Invalid buffer id: 15968` and `Invalid buffer id: 15970` count as one fault with two hits,
not two novel faults. that is what makes a stale-handle storm legible as a single defect.

read two columns together:

- **hits** — the total toll this fault has taken
- **sessions** — how many distinct nvim instances hit it

high hits + low sessions = one session stormed (a runaway loop; suspect a timer or an
autocmd that refires). high hits + high sessions = a reproducible fault in the config
(suspect a plugin contract we hold wrong).

## .how to debug a ranked fault

the rank tells you *what* costs the most. these four moves take you from that line to the
cause.

### 1. un-escape the traceback

the log keeps one error per line, so a multi-line traceback is written with ` \n ` as the
line break. pull the raw record and read the breaks as newlines:

```sh
rhx nvim.errors.review --grep 'Invalid buffer id' --tail 5
```

### 2. read the traceback for the culprit frame

frames run innermost-first. two frames matter:

- the **first frame that is not `[C]` and not `src/grove.provision/4.terminal/4.5.nvim/init.lua`** — that is the plugin that threw
- the **last `src/grove.provision/4.terminal/4.5.nvim/init.lua:NNN` frame** — that is *our* handler that invoked it

a real capture from this repo:

```
stack traceback: \n ...neominimap/command/global.lua:19: in function 'impl'
 \n ...plugin/neominimap.lua:15 \n [C]: in function 'nvim_exec2'
 \n [C]: in function 'pcall' \n /home/vlad/git/more/dev-env-setup/src/grove.provision/4.terminal/4.5.nvim/init.lua:816
```

reads as: our handler at `init.lua:816` ran a neominimap command, which threw at
`global.lua:19`. that pair — our line and their line — is the whole diagnosis. our line is
what we can change; their line tells us which contract we hold wrong.

### 3. reproduce headless

headless is the fast loop: no terminal, no session to lose, seconds per run.

```sh
# just boot the config and exit — catches load-time and quit-path faults
nvim --headless -u src/grove.provision/4.terminal/4.5.nvim/init.lua -c "sleep 2" -c "qa!"

# drive a specific codepath
nvim --headless -u src/grove.provision/4.terminal/4.5.nvim/init.lua -c "Neominimap Refresh" -c "sleep 2" -c "qa!"
```

the scribe writes to the same global log from a headless run, so
`rhx nvim.errors.review --since 5m` reads back what the run threw. two caveats: headless
always emits an `image.nvim: cannot query terminal size` notice (an artifact of no tty, not
a fault), and it loads the **repo** config via `-u src/grove.provision/4.terminal/4.5.nvim/init.lua`, not the synced one — which
is what you want while you iterate.

### 4. confirm the repair with the log

the log is the regression test. after the fix, re-run the reproduction and check the fault is
absent from `--since 5m`. absence there is the proof, the same role a red-then-green test
plays (`rule.require.clamp-edge-cases`).

## .what to do with a ranked fault

1. **name the cause, not the symptom** — the captured traceback names the file that threw.
   `rule.require.solve-at-cause`: fix at that source, do not wrap the call site in a pcall
   to quiet the log.
2. **fix it in `src/grove.provision/4.terminal/4.5.nvim/init.lua`**, never in `~/.config/nvim/init.lua` —
   `rule.require.repo-as-source-of-truth`.
3. **verify headless** — `rhx nvim.test.headless --check src/grove.provision/4.terminal/4.5.nvim/init.lua`
   (`rule.require.invoke-rhx-by-its-bare-name` — never the path)
4. **apply** — `rhx grove.provision --what 4.5.nvim --mode apply`
5. **confirm it stopped** — `rhx nvim.errors.review --since 1d --grep <signature>` after a
   day of use. the log is the proof the repair held, the same way a regression test is
   (`rule.require.clamp-edge-cases`).

## .when the log is silent but you saw an error

an absent record is not proof of an absent fault. check these five before you conclude the
error did not happen:

| cause | tell | fix |
|-------|------|-----|
| the scribe is not live | log file absent entirely | `rhx grove.provision --what 4.5.nvim --mode apply`, reopen nvim |
| **the live config DRIFTED from the repo** | the log exists and its newest lines are all headless artifacts — no line from an interactive session | `cmp` the two, then apply. see below |
| the repeat window swallowed it | the fault IS there, with an old timestamp and a high `n=` | read `n=`, not the line count — one line can stand for thousands of hits |
| the session died hard | last session's faults absent | the exit flush runs on `VimLeavePre`; a `kill -9` skips it, so up to 5s of faults are lost |
| a plugin stole `vim.notify` | plugin-reported warns absent, runtime errors still captured | the re-wrap runs once at `VimEnter`; a plugin that swaps `vim.notify` later bypasses channel 1 |

channel 2 (the `:messages` poll) is the durable one — it catches what the runtime throws
regardless of who owns `vim.notify`. it is **proven**, not merely asserted: a deliberate
canary drove it red then green on 2026-08-11, and both rows are still in the log —

```
2026-08-11T22:47:32 pid=3425180 src=messages … E999: SATURATION-CANARY
2026-08-11T22:49:11 pid=3435478 src=messages … E999: FIXED-CANARY
```

## 🛑 .row 2 is the one that reads as a CLEAN BILL — measured 2026-09-06

a human reported a live `vim.schedule callback: … Invalid buffer id: 2` on this box. the
reader answered:

```
🔭 nvim.errors.review --grep Invalid buffer id
   └─ 0 errors in scope
```

⚠️ **a `0` there was about to be read as "the repair held."** it was not. the log's newest 33
lines were `src=notify.warn … image.nvim: cannot query terminal size` — the tty artifact a
HEADLESS run always emits, so every one came from a probe rather than from a session. the last
line an interactive nvim wrote was **2026-08-11**, ~26 days earlier.

the cause was `~/.config/nvim/init.lua` drifted **274 lines** from the repo copy, so the scribe
a human's session actually ran was not the scribe the repo declares — a **silent detector
outage**, and precisely what `rule.require.repo-as-source-of-truth` exists to prevent.

⇒ the two-part tell, and it costs one command:

```sh
cmp -s ~/.config/nvim/init.lua src/grove.provision/4.terminal/4.5.nvim/init.lua \
  && echo "config in sync" || echo "DRIFTED — the scribe you ran is not the one declared"
```

then read WHOSE lines are newest. `src=notify.warn` + `image.nvim: cannot query terminal size`
is the headless signature; a log whose recent lines are all that shape has heard from no human
session at all, whatever its line count says.

⇒ 🛑 so **`0 errors in scope` is a claim about the LOG, never about the box**. before you cite
an absence as proof a repair held (step 4 above), confirm the log has heard from a session of
the kind that would have thrown — otherwise it is a false ✔ read off an unwritten channel
(`gotcha.a-check-that-cries-wolf-gets-silenced`, q13: which store did this count consult?).

## .the log beside it

`~/.local/state/nvim/selfwatch.log` is the *memory* trend log from the self-watchdog (rss,
buffer count, treesitter count). read it next to `errors.log` when a fault correlates with
growth — an error storm and a leak are often the same defect seen from two angles.

## .see also

- `.agent/repo=.this/role=any/skills/nvim.errors.review.sh` — the reader
- `.agent/repo=.this/role=any/briefs/desktop/nvim/howto.diagnose-nvim-hang.md` — when it is frozen right now
- `.agent/repo=.this/role=any/briefs/desktop/nvim/nvim.hazard.async-refresh-on-quit.md` — a known fault class
- `src/grove.provision/4.terminal/4.5.nvim/init.lua` — the "error scribe" block that writes the log
