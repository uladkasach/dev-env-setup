# howto: diagnose nvim hang

## .what

detect and diagnose nvim processes that consume excessive CPU or memory.

## .expected baseline

idle nvim should use:
- CPU: 0% (literally zero when unfocused or no activity)
- memory: ~100-300MB (varies by plugins and open buffers)

## .symptoms

| symptom | likely cause |
|---------|--------------|
| 100% CPU sustained | infinite loop (treesitter, neominimap, autocmd cycle) |
| 10-30% CPU idle | busy poll loop (timer, git status poll) |
| memory grows over time | lua table allocation without cleanup, cache unbounded |
| memory spike on action | O(n²) algorithm, large buffer process |

## .detection

### find runaway nvim

```bash
# quick check
ps aux | grep nvim | grep -v grep

# with CPU time (TIME+ column shows accumulated CPU seconds)
top -b -n1 | grep nvim
```

### thresholds

| metric | normal | suspicious | critical |
|--------|--------|------------|----------|
| %CPU | 0% | >5% idle | >50% |
| %MEM | <1% | >3% | >10% |
| TIME+ | <1min | >10min | >30min |
| RES | <500M | >1G | >2G |

## .diagnosis with strace

### attach to suspect process

```bash
sudo strace -p <PID> -f 2>&1 | head -100
```

### patterns to look for

| strace pattern | diagnosis |
|----------------|-----------|
| repeated `getcwd()` | FileType autocmd loop |
| repeated `access(...ftplugin...)` | filetype detection loop |
| `epoll_pwait(..., 0, ...)` (timeout=0) | busy poll, timer too aggressive |
| `epoll_pwait(..., -1, ...)` | normal idle (wait forever) |
| `clone()` spawn children | git commands (gitsigns, lualine) |
| `statx()` on git paths | git status poll |

### example: treesitter/neominimap loop

```
getcwd("/path/to/worktree", 4096) = 81
getcwd("/path/to/worktree", 4096) = 81
access("...ftplugin/neominimap/", R_OK) = -1
access("...ftplugin/neominimap/", R_OK) = -1
```

diagnosis: FileType autocmd fires, triggers neominimap, which triggers FileType again.

### example: busy poll

```
epoll_pwait(3, [], 1024, 0, NULL, 8) = 0
epoll_pwait(3, [], 1024, 0, NULL, 8) = 0
epoll_pwait(3, [], 1024, 15, NULL, 8) = 0
```

diagnosis: timer with 0ms timeout causes busy wait. look for timer_start with short intervals.

## .common root causes

| cause | fix |
|-------|-----|
| treesitter on virtual buffers | skip if `buftype ~= ''` |
| treesitter on neominimap | skip if `filetype == 'neominimap'` |
| vdiff handler per-line iteration | use changedtick cache, debounce |
| no focus gate | skip work when `FocusLost` |
| unbounded cache | clean on `BufDelete`/`BufWipeout` |

## .kill

```bash
# graceful (may not work if hung)
kill <PID>

# force (always works)
kill -9 <PID>
```

## .prevention

in init.lua:

```lua
-- global focus state
local nvim_focused = true
vim.api.nvim_create_autocmd('FocusLost', {
  callback = function() nvim_focused = false end,
})
vim.api.nvim_create_autocmd('FocusGained', {
  callback = function() nvim_focused = true end,
})

-- skip treesitter on virtual/special buffers
vim.api.nvim_create_autocmd('FileType', {
  callback = function()
    if not nvim_focused then return end
    if vim.bo.buftype ~= '' then return end
    if vim.bo.filetype == 'neominimap' then return end
    pcall(vim.treesitter.start)
  end,
})
```

## .defense layers (2026-07-22)

two guards now cap nvim so no single core can freeze the machine.

### layer 1 — systemd memory cap (`nvim()` wrapper)

`src/bash_aliases.sh` defines an `nvim()` function that launches nvim inside a
systemd user scope:

- `MemoryHigh=1500M` — kernel throttles + reclaims (graceful)
- `MemoryMax=2G` — hard wall; kernel refuses to grow past it

the kernel physically prevents any one nvim from growth past 2G, so a leak can
never thrash swap. plugin-agnostic — works no matter which subsystem leaks.

verify a live nvim is capped:

```bash
systemctl --user status | grep -A3 nvim   # shows the nvim scope + MemoryMax
```

### layer 2 — in-nvim self-watchdog (`init.lua`)

a 30s timer reads `/proc/self` RSS+CPU and acts before the kernel cap bites:

- **warn** at 0.8G → append a trend line to the log (below)
- **trip** at 1.2G → `Neominimap off` + `treesitter.stop` all buffers + GC +
  `notify-send`. self-heal, not kill — buffers survive.

order: watchdog trips (1.2G) → systemd throttles (1.5G) → hard cap (2G).

## .the evidence log — how to use it

the watchdog writes `~/.local/state/nvim/selfwatch.log` (path =
`stdpath('state')/selfwatch.log`).

```bash
tail -f ~/.local/state/nvim/selfwatch.log
```

each line past 0.8G:

```
2026-07-22T09:30:01 rss_mb=843 cpu_ticks=12 bufs=7 ts=3 tripped=false cwd=/home/vlad/git/...
```

read the columns to name the leak without a guess:

| column | means | what a climb implies |
|--------|-------|----------------------|
| `rss_mb` | resident memory | the leak magnitude |
| `cpu_ticks` | cpu burned per 30s window | high + flat rss = spin, not leak |
| `bufs` | open buffers | climbs with rss ⇒ buffer/undo leak |
| `ts` | buffers with active treesitter | climbs with rss ⇒ treesitter is the leak |
| `tripped` | breaker fired yet | `true` = handlers already disabled |

**the diagnosis rule:** find which column climbs alongside `rss_mb`.

- `ts` climbs → treesitter; bound it / skip huge buffers
- `bufs` climbs → buffer or undo accumulation; clean on `BufWipeout`
- `rss` climbs while `ts`+`bufs` stay flat → neominimap vdiff cache or
  image.nvim; those are the residual suspects
- a `TRIP` line + no further growth → breaker worked as designed

then patch THAT handler at source (see `.common root causes` above). this closes
the loop the two prior blind attempts left open (`.behavior/v2026_06_02.fix-nvim-hang`).

## .inspect a LIVE process (before you reap)

use the `nvim.inspect.embed.sh` skill — read-only `/proc` walk that names the
spawner and the hot loop without root:

```bash
.agent/repo=.this/role=any/skills/nvim.inspect.embed.sh --all
```

it prints, per nvim: parent chain (the spawner), environ fingerprint, and
per-thread **wchan + cpu-secs**. a thread in state `R` whose wchan reads
`(run/userspace)` with high cpu-secs is the live hot loop. capture this BEFORE
`kill -9`, or the evidence dies with the process.

## .see also

- system.runaway_monitor.spec.md — general runaway process detection
- nvim.neominimap.custom-handler.md — vdiff handler with proper cache
- src/bash_aliases.sh — the `nvim()` memory-cap wrapper (layer 1)
- src/init.lua — the self-watchdog block (layer 2), search `self-watchdog`
- .agent/**/skills/nvim.inspect.embed.sh — live /proc inspector
