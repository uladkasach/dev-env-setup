-- .what = resize the codediff explorer 5 times in a burst, the way a held alt+l
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

vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
local ex
if not vim.wait(30000, function() ex = lc.get_explorer(vim.api.nvim_get_current_tabpage()); return ex and ex.tree and ex.winid end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
vim.wait(2000, function() return false end, 50)
say('world=present n=' .. N)

local Tree = require('codediff.ui.lib.tree')
local renders = 0
local r0 = Tree.render
Tree.render = function(self, ...) if self == ex.tree then renders = renders + 1 end; return r0(self, ...) end

-- the burst: five 3-column steps, 20ms apart, as a held key repeats
local w = vim.api.nvim_win_get_width(ex.winid)
for k = 1, 5 do
  vim.api.nvim_win_set_width(ex.winid, w + 3 * k)
  vim.api.nvim_exec_autocmds('WinResized', {})
  vim.wait(20, function() return false end, 5)
end
vim.wait(500, function() return false end, 10)
say(('renders_per_burst=%d width_after=%d width_rendered=%s'):format(renders, vim.api.nvim_win_get_width(ex.winid), tostring(ex.__cd_width)))
quit()
