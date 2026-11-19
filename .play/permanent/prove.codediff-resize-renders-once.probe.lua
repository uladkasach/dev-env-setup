-- .what = resize the codediff explorer 5 times in one burst, the way a held alt+l
--         does, and count how many tree renders the burst cost
--
-- .why  = measured 2026-10-07 at 1000 files: codediff re-rendered the whole tree on
--         every resize step — 1101 rows rebuilt, 40-100ms each, 0 rows changed —
--         so a held key queued one full render per step (init.lua, the
--         render_mod.create wrapper, debounces it to one)
--
-- .the contract with its driver (`rhx nvim.test.headless --probe`)
--   PROBE_ARM  control | old-per-step
--   PROBE_OUT  where to write the rows
--
-- .the arms
--   control       as shipped → renders_per_burst=1
--   old-per-step  `_G.codediff_resize_debounce_ms = 0` → one render per step (5).
--                 if it reads 1, this probe cannot see the defect (term=bite)
--
-- ⚠️ headless nvim has no UI, so a real resize fires no WinResized. the probe sets
--    the width and fires the event itself — which is why the shipped hook reads
--    the explorer's WIDTH rather than v:event
--
-- .the rows
--   world=<present|absent> n=<files>
--   trace <k> t=<ms since burst> <stack>   one per counted render, so a red names its caller
--   renders_per_burst=<n> width_after=<cols> width_rendered=<cols>

local out = vim.fn.fnamemodify(os.getenv('PROBE_OUT'), ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end
local N = 200

local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
sh('git init -q && git config user.email p@p && git config user.name p')
local function path_of(i) return ('%s/src/area-%d/record-%04d.ts'):format(root, i % 7, i) end
for i = 1, N do vim.fn.mkdir(vim.fn.fnamemodify(path_of(i), ':h'), 'p'); vim.fn.writefile({ 'a' .. i }, path_of(i)) end
sh('git add -A && git commit -qm init')
for i = 1, N do vim.fn.writefile({ 'b' .. i }, path_of(i)) end
vim.cmd('cd ' .. vim.fn.fnameescape(root))

-- wait on the FIX itself, never a clock
pcall(require, 'codediff')
if not vim.wait(20000, function() return _G.codediff_resize_debounce_ms ~= nil end, 20) then
  say('world=absent reason=resize_wrapper_never_installed')
  return quit()
end
if arm == 'old-per-step' then _G.codediff_resize_debounce_ms = 0 end

-- the line-change % is a SECOND render source, off for this probe
--   ⚠️ its pass is async (a git numstat, then line counts on the libuv pool) and renders
--     once its % map moves. on a loaded box that render landed in the counted window
--     long after the tree read quiet: control 2, old 6, each trace from `lp_render`.
--     📜 measured 2026-11-18 inside `play.run --all`. the % has its own clamp
--     (`prove.codediff-line-pct`); this probe counts the resize hook alone, as the
--     refresh probe does (init.lua, `.off`)
_G.codediff_line_pct = false

vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
local ex
if not vim.wait(30000, function() ex = lc.get_explorer(vim.api.nvim_get_current_tabpage()); return ex and ex.tree and ex.winid end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
say('world=present n=' .. N)

local Tree = require('codediff.ui.lib.tree')
local renders = 0
local measured = nil
local last_render = vim.uv.now()
local r0 = Tree.render
Tree.render = function(self, ...)
  if self == ex.tree then
    renders = renders + 1; last_render = vim.uv.now()
    if measured then say(('trace %d t=%d %s'):format(renders, vim.uv.now() - measured, (debug.traceback('', 2):gsub('\n%s*', ' | ')))) end
  end
  return r0(self, ...)
end

-- wait for the tree to go QUIET before the burst, never a fixed sleep
--   ⚠️ codediff renders the tree again on its own after open (a background refresh).
--     a fixed 2s settle let that render land inside the measured window on a loaded
--     box: both arms read +1 (2 and 6). 📜 measured 2026-11-17 inside `play.run --all`
--   quiet = 1500ms with no render; bounded at 30s
if not vim.wait(30000, function() return vim.uv.now() - last_render >= 1500 end, 50) then
  say('world=absent reason=tree_never_quiet')
  return quit()
end
-- the burst: five 3-column steps 20ms apart, as a held key repeats
--   the gaps are LOAD-BEARING: a debounce cut short (80ms → 10ms) still collapses a
--   burst that runs in one tick, so only a gapped burst can see it go red
--   ⚠️ a loaded box can stretch one gap past the window, so the timer fires mid-burst
--     and the control reads 2 — a clock race, not the hook. 📜 measured 2026-11-17,
--     red inside `play.run --all` only. so each gap is TIMED: a burst with a gap that
--     reached the window proves naught, and is run again once the tree goes quiet
--   the old arm (debounce 0) renders synchronously, so no gap can stretch it
local window = _G.codediff_resize_debounce_ms
local function burst()
  local w = vim.api.nvim_win_get_width(ex.winid)
  local gap_max, prev = 0, nil
  for k = 1, 5 do
    local now = vim.uv.now()
    if prev then gap_max = math.max(gap_max, now - prev) end
    prev = now
    vim.api.nvim_win_set_width(ex.winid, w + 3 * k)
    vim.api.nvim_exec_autocmds('WinResized', {})
    if k < 5 then vim.wait(20, function() return false end, 5) end
  end
  return gap_max
end

local tries, gap_max = 0, nil
repeat
  tries = tries + 1
  renders = 0
  measured = vim.uv.now()
  gap_max = burst()
  vim.wait(500, function() return false end, 10)
  -- a stretched burst: let its own render land and the tree go quiet, then try again
  local stretched = window > 0 and gap_max >= window - 5
  if not stretched then break end
  say(('burst %d stretched: gap_max=%dms reached the %dms window, so it proves naught'):format(tries, gap_max, window))
  vim.wait(30000, function() return vim.uv.now() - last_render >= 1500 end, 50)
until tries >= 5

if window > 0 and gap_max >= window - 5 then
  say(('world=absent reason=every_burst_stretched tries=%d'):format(tries))
  return quit()
end
say(('renders_per_burst=%d width_after=%d width_rendered=%s gap_max=%dms tries=%d'):format(renders, vim.api.nvim_win_get_width(ex.winid), tostring(ex.__cd_width), gap_max, tries))
quit()
