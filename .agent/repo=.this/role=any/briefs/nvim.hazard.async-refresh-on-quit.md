# nvim.hazard.async-refresh-on-quit

## .what

a plugin that schedules async window work (via `vim.schedule` /
`vim.defer_fn`) off `WinClosed` / `BufWinEnter` / `WinNew` can crash and
**permahang** nvim on `:q`, because the scheduled callback runs mid-teardown
against a half-destroyed window.

first hit with `neominimap` (the split minimap), but the pattern is general —
any plugin with this shape is a suspect.

## .the symptom

on quit, a burst of errors like:

```
[C]: in function 'nvim_win_set_buf'
...neominimap/window/split/internal.lua:300: in function 'refresh_source_in_current_tab'
...neominimap/window/split/autocmds.lua:21
vim.schedule callback: ...internal.lua:300: Keyboard interrupt
```

then nvim hangs and will not quit. `Ctrl-C` only makes it worse.

## .why it hangs (the mechanism)

1. `:q` fires window/buffer teardown autocmds (`WinClosed`, `BufWinEnter`).
2. the plugin's handler does `vim.schedule(refresh)` — the refresh runs on the
   **next** loop tick, i.e. *after* teardown has begun.
3. the refresh calls `nvim_win_set_buf(minimap_win, …)` on a window that is now
   half-destroyed → it throws.
4. the error prints to the **`-- More --`** pager, which halts for a keypress.
5. but more queued `vim.schedule` callbacks keep firing, each throws, each adds
   to the pager — so the pager never clears.
6. `Ctrl-C` aborts a callback mid-`set_buf`, which leaves the plugin's internal
   window map half-updated, so the next callback throws too. **deadlock.**

"sometimes" = it only races when a scheduled refresh lands inside the teardown
window. depends on split/tab count and whether the minimap was last-focused.
single-window quits usually miss it.

## .the fix

disable the plugin's refresh machinery **before** teardown, on `QuitPre` /
`VimLeavePre`, so no scheduled callback reaches the window API at quit time:

```lua
vim.api.nvim_create_autocmd({ 'QuitPre', 'VimLeavePre' }, {
  callback = function()
    pcall(vim.cmd, 'silent! Neominimap off')
  end,
})
```

once off, the already-queued callbacks re-check the plugin's enabled flag and
take the harmless "no minimap" branch instead of the `set_buf` path.

lives in `src/init.lua` inside the neominimap `config`. it is a config-level
guard, so it survives plugin updates.

## .the general rule

when a plugin schedules window mutation off teardown events, gate it on quit.
watch for this shape:

```lua
-- HAZARD: async window mutation off a teardown event
vim.api.nvim_create_autocmd({ 'WinClosed', 'BufWinEnter' }, {
  callback = function()
    vim.schedule(function()
      vim.api.nvim_win_set_buf(some_win, some_buf)  -- may run mid-teardown
    end)
  end,
})
```

mitigations, in order of preference:

1. **disable on `QuitPre`/`VimLeavePre`** (what we did) — cheapest, robust.
2. inside the scheduled callback, bail early if quit has begun
   (`if vim.v.exiting ~= vim.NIL then return end`) or if the window is gone
   (`if not vim.api.nvim_win_is_valid(win) then return end`).
3. a high `cmdheight` or `shortmess+=` only hides the `-- More --` pager, not
   the root race — prefer option 1.

## .aggravator to check

an autocmd that force-quits (`vim.cmd('quit!')`) from a `WinEnter`/focus handler
can run *while* the async refresh chain still drains, which makes the race
easier to hit. init.lua had one (to make the minimap unfocusable). the `QuitPre`
guard above neutralizes the crash regardless, but a force-quit mid-drain is a
second hazard worth a look.

## .to escape a live hang

keystrokes won't save it (stuck in `-- More --`). from another terminal:

```sh
kill <nvim-pid>     # or kill -9 if it ignores TERM
```

reopen at the same cwd via `kitty.snap` records if you took one.

## .see also

- howto.diagnose-nvim-hang.md — general nvim runaway/hang triage
- nvim.neominimap.custom-handler.md — the vdiff handler (another async surface)
- src/init.lua — the `QuitPre` guard, in the neominimap `config` block
