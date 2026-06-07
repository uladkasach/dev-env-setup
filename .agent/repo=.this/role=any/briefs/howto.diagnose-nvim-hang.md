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

## .see also

- system.runaway_monitor.spec.md — general runaway process detection
- nvim.neominimap.custom-handler.md — vdiff handler with proper cache
