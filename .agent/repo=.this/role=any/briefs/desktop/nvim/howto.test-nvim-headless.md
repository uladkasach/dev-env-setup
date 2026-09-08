# howto: test nvim config + lua headlessly

## .what

run nvim's lua logic (config, plugin glue, utils) without a human at a terminal —
for CI, agent loops, and fast feedback. two levels: **parse** (syntax only) and
**run** (real nvim runtime, real `vim.*` api).

## .why

- nvim config is lua; lua bugs otherwise surface only when a human opens the
  editor. headless testing catches them in seconds.
- `nvim --headless` boots a full nvim (real `vim.api`, `vim.system`, `vim.fn`),
  so tests exercise the true runtime, not a mock.
- pairs with the repo skill `nvim.test.headless` (see below) so an agent can
  verify nvim-side changes via `rhx`.

## .the skill (preferred path)

```sh
rhx nvim.test.headless --check src/init.lua        # parse only (loadfile, no exec)
rhx nvim.test.headless --run tests/foo.test.lua    # run a lua test file
rhx nvim.test.headless --run tests/foo.test.lua --clean  # -u NONE (no user config)
rhx nvim.test.headless --lua "print(1+1)"          # inline snippet
```

exit codes: `0` pass, `1` malfunction (nvim errored / test failed / syntax
error), `2` constraint (bad args, file absent, nvim absent).

## .the raw commands (what the skill wraps)

### parse only — no execution

`loadfile` compiles the chunk but does NOT run it, so it needs no plugins and
catches pure syntax errors:

```sh
nvim --headless -c "lua local ok,err=loadfile('src/init.lua'); print(ok and 'SYNTAX OK' or ('ERR: '..vim.inspect(err)))" -c "qa"
```

use this on a full `init.lua` — it will NOT trigger the plugin `require`s, so it
is safe even when plugins are absent.

### run a lua test file

`-l FILE` runs FILE as a lua chunk in a real nvim, then exits. `os.exit(code)`
sets the process exit code — make failures authoritative:

```sh
nvim --headless -l tests/foo.test.lua
```

### run against a clean config

`-u NONE` skips the user's `init.lua` so a test does not inherit local config:

```sh
nvim --headless -u NONE -l tests/foo.test.lua
```

## .how to write a headless lua test

a good test prints clear `PASS`/`FAIL` lines and exits non-zero on any failure:

```lua
local fails = 0
local function check(name, cond)
  print((cond and 'PASS ' or 'FAIL ') .. name)
  if not cond then fails = fails + 1 end
end

-- pure logic
check('adds', (1 + 1) == 2)

-- real vim.* api is available
check('cwd is a string', type(vim.fn.getcwd()) == 'string')

-- real subprocess via vim.system (nvim 0.10+); text=false keeps bytes intact
local res = vim.system({ 'git', 'rev-parse', '--show-toplevel' }):wait()
check('git ok', res.code == 0)

os.exit(fails > 0 and 1 or 0)  -- authoritative exit code
```

## 🛑 .a probe of a PLUGIN interaction needs the third invocation

the two above are `-u NONE` (isolate the snippet) and `-l file` (run a test, no config).
both **delete the subject** when what you are testing is our config's contract with a
plugin — the fault lives in the interaction, so a run without plugins cannot see it.

that case wants the full real config, then a probe driven against it — and the skill owns
that shape:

```sh
rhx nvim.test.headless --probe <probe>.lua --arm control --arm old
```

it boots `-u <the repo's 4.5.nvim init.lua>` (override with `--config`), drives one nvim
per `--arm`, hands each `PROBE_ARM` + `PROBE_OUT`, bounds each at `--within` seconds, and
prints the rows an arm wrote. the raw form it wraps:

```sh
nvim --headless -u <config> -c "luafile <probe>"
```

⚠️ **it is `luafile`, not `-l`.** `-l` runs its chunk with no `init.lua` loaded, which is
the very case this shape exists to avoid.

🛑 **reach for the skill, never the raw form.** the raw form was typed by hand for a day
and it cost two things: a brittle exact-match permission entry that named a *scratch* path,
and — the expensive one — a SECOND copy of the probe body under `.play/temporary/`, because
the play that owned the body kept it in a heredoc and no runner could drive it. one probe,
two copies, free to drift: the m.9 defect, committed inside the probe written to close m.9
(`rule.forbid.adhoc-shell`).

⇒ so a probe body is its **own tracked file**, beside the play that judges it. the play
holds the claim and the verdicts; the skill holds the invocation; the probe holds the
measurement. `prove.breaker-spares-cached-buffers.{play.sh,probe.lua}` is the worked pair.

### the driver/judge split, and why the skill declares no verdict

`nvim.test.headless --probe` reports whether each arm **ran and spoke**. it never says
whether a row holds the value the caller hoped for — the play that owns the claim does
that. so its exit codes read:

| exit | means |
|---|---|
| 0 | every arm ran and wrote rows — read them and judge |
| 1 | an arm wrote no rows, or hit the bound. it asked NO question |
| 2 | an arm reported `world=absent` — its own fixture did not take |

⚠️ a mute arm is never a negative answer. that read is the false ✔ the split exists to make
impossible (`rule.forbid.failhide`).

⚠️ and the probe must write to `os.getenv('PROBE_OUT')`. a probe that picks its own `$HOME`
path is a `rule.forbid.fixed-paths-in-a-shared-tmp` defect, and it reports here as mute.

## 🛑 .one arm proves none of it — a probe ships in PAIRS

a single green run says the code ran. it does not say the check can go red, and a check
never seen to fail is unproven in exactly the direction that matters
(`gotcha.a-check-that-cries-wolf-gets-silenced`, `.the corollary`).

so key the probe on an arm and drive each:

| arm | what it builds | what it must print |
|---|---|---|
| `control` | the healthy world, untouched | ✔ — the subject works |
| `old` | the defect, planted on purpose | ✋ — the check BITES |
| `fixed` | the defect, plus the repair | ✔ — the repair holds |

```sh
rhx nvim.test.headless --probe <probe>.lua --arm control --arm old --arm fixed
```

⚠️ `old` green is the tell that the probe measures the wrong subject. treat it as a defect
in the probe, never as evidence about the subject (`term=bite`).

### 🛑 the break must reach the reader that runs IN ANGER, not a copy of its reference

measured 2026-09-07, and it is the sharpest form of m.9 yet seen here. the breaker's
keep-set reader was exposed on `_G` so a probe could call it. the `old` arm then broke it
the obvious way:

```lua
_G.nvim_selfwatch.get_buffers_unwipeable = function() return {} end
```

**both arms went green.** the `_G` field holds a *copy of the reference*; the shipped
`trip_breaker` reads a **local upvalue**. so the break landed on a holder no code reads, the
wipe ran with the real keep-set, and the control arm's ✔ proved none of what it claimed.

⇒ the repair is an **injected reader** in the shipped code: `trip_breaker(rss_mb, get_keep)`,
where the shipped caller passes no reader and the probe passes a neutered one. an argument
reaches the reader in anger and — unlike a `_G` read — cannot be clobbered by any other
plugin that shares the lua state, which matters because this one guards a *delete*
(`rule.require.dependency-injection`).

⚠️ **not "a seam."** this repo spends that word on one sense already — the link *between*
two components, owned by neither (`rule.require.seam-claims-have-an-owner`, which carries an
audit table of every one). the industry sense is a different concept, and one word on two
concepts is the overload the glossary exists to prevent.

⇒ and the tell that named the cause was a **census row**, not the verdict: the probe now
reports `cached_ft` and `minimap_bufs`, the exact keys the wipe matches on. without them, "a
fixture that built no minimap buffer" and "a break aimed at the wrong holder" print
identically (`gotcha.a-check-that-cries-wolf-gets-silenced`, q1 — print what you observed,
not only what you concluded).

### 🛑 an expectation the probe never checked is a claim, not a measurement

the same play also demanded `refresh_ok=false` from its `old` arm, on the reasoning that a
plugin robbed of its cached buffer must break. the first arm that actually ran it showed
that is **false** — `Neominimap refresh` survives the delete.

⇒ the expectation was dropped and the measurement kept. bend it the other way and the play
would report a red arm forever, against correct code, until somebody silenced it. an
unmeasured expectation inside a probe is the same defect the probe exists to catch, one
level up.

### ⚠️ it is a WRITE play, so `rule.forbid.repair-plays` governs where it lives

the `old` arm breaks the box on purpose, so this is exception 2 — a **discrimination
probe** — and its four conditions bind in full: a `trap … EXIT` restore, a refusal to run
on an absent subject, a break narrow enough to implicate one check, and a report of
whether the restore took.

⇒ that also fixes the DIRECTORY, and the two halves point opposite ways:

- a probe still under **iteration** is scratch — `.play/temporary/`, gitignored
- a probe that **ships as a clamp** belongs TRACKED. exception 2 calls a discrimination
  probe filed under `.play/temporary/` a blocker: that dir reaches no other box, so the
  clamp's absence would be silent

## 🛑 .the two ways this shape lies, both measured 2026-09-06

### it waits on a CLOCK for a world it never reads back

`-c "sleep 2"` and a `vim.defer_fn(…, 1500)` are the same proxy: a wall-clock stand-in for
*"are the plugins loaded yet?"* the direct signal exists and is one line —

```
lazy/init.lua:115   nvim_exec_autocmds("User", { pattern = "LazyDone", modeline = false })
```

⇒ wait on `User LazyDone`, or the probe owes a **read-back that its world exists**. a
probe's short-direction fault does not report a defect; it reports a verdict about a world
nobody built, and it goes GREEN (`rule.prefer.deterministic-signal-over-timer`, the second
measurement; `gotcha.a-check-that-cries-wolf-gets-silenced`, q5).

### it re-implements the predicate instead of CALLING it

a probe that rebuilds the shipped logic inline has cut one set into two readers, and the
half that runs in anger is the half no arm touched — so the shipped path can be wrong while
every arm stays green (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9).

⚠️ a `local function` inside a `do … end` block is **structurally unreachable** from a
probe, so this one is not a discipline failure — it is a shape failure. to make the
contract testable, the function has to be reachable.

## .gotchas

- **byte-safe subprocess**: for binary output (e.g. `git show HEAD:image.png`)
  use `vim.system({...}, { text = false })` and write with `io.open(path,'wb')`.
  lua strings are byte arrays, so this preserves bytes; `systemlist` /
  `vim.split` on `\n` will corrupt binary.
- **image.nvim warning**: headless prints `image.nvim: cannot query terminal
  size (non-terminal environment?)`. harmless — headless has no tty. it is NOT a
  test failure; the skill's fail-scan ignores it.
- **what headless CANNOT test**: anything that needs a real tty or the kitty
  graphics protocol — actual image render, window pixel layout, true keypress
  routing. those stay manual-verify in a live kitty nvim. headless proves the
  *logic* (path detection, git extraction, branch decisions); the human proves
  the *pixels*.
- **`-l` vs `-c "lua ..."`**: `-l FILE` runs a file and respects `os.exit`;
  `-c "lua ..."` runs an inline chunk then you must `-c "qa"` to quit. prefer
  `-l` for test files.
- **avoid full-config side effects**: `-l` does NOT load your `init.lua`, but
  `-c "lua ..."` (without `-u NONE`) DOES. use `--check`/loadfile or `-u NONE`
  when you only want to test a snippet in isolation.

## .see also

- skill: `.agent/repo=.this/role=any/skills/nvim.test.headless.sh` — invoke it as
  `rhx nvim.test.headless`, never by this path (`rule.require.invoke-rhx-by-its-bare-name`)
- brief: `howto.diagnose-nvim-hang.md` (runtime diagnosis, not testing)
- brief: `howto.review-nvim-errors.md` — a headless run writes to the same global error
  log, so `rhx nvim.errors.review --since 5m` reads back what an arm threw
- rule: `rule.forbid.repair-plays` — exception 2, the four conditions a probe that writes owes
- rule: `rule.prefer.deterministic-signal-over-timer` — why `sleep 2` is a proxy
- gotcha: `gotcha.a-check-that-cries-wolf-gets-silenced` — q5 (did the fixture take?) and
  m.9 (one set, two readers)
