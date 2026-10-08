-- .what = press ctrl+alt+r in each kind of codediff buffer and read what lands in
--         the clipboard, against the path each owes (criteria: codediff.copy-path)
--
-- .the rows
--   file_row   explorer, cursor on aa/a1.txt      → owes aa/a1.txt
--   dir_row    explorer, cursor on the aa/ row    → owes aa
--   rev_pane   the revision side of a1's diff      → owes aa/a1.txt
--   plain_buf  an ordinary buffer on bb/b1.txt     → owes bb/b1.txt
--
-- .the arms
--   control    as shipped → every row hit
--   old-label  `_G.codediff_copy_path = false` → file_row copies the explorer's
--              buffer label (the defect). if it hits, this probe cannot see it
--
-- ⚠️ headless nvim has no clipboard provider, so the probe captures setreg('+')
--
-- .rows written: world=…, then <row>=<hit|miss> want=<path> got=<copied>

local out = vim.fn.fnamemodify(os.getenv('PROBE_OUT'), ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/aa', 'p'); vim.fn.mkdir(root .. '/bb', 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
sh('git init -q && git config user.email p@p && git config user.name p')
for _, f in ipairs({ 'aa/a1.txt', 'aa/a2.txt', 'bb/b1.txt' }) do vim.fn.writefile({ 'x' }, root .. '/' .. f) end
sh('git add -A && git commit -qm init')
for _, f in ipairs({ 'aa/a1.txt', 'aa/a2.txt' }) do vim.fn.writefile({ 'y' }, root .. '/' .. f) end
vim.cmd('cd ' .. vim.fn.fnameescape(root))

pcall(require, 'codediff')
if not vim.wait(20000, function() return _G.codediff_resize_debounce_ms ~= nil end, 20) then
  say('world=absent reason=config_never_loaded')
  return quit()
end
if arm == 'old-label' then _G.codediff_copy_path = false end

-- capture what the copy writes to the clipboard register
local copied
local shipped_setreg = vim.fn.setreg
vim.fn.setreg = function(reg, val, ...) if reg == '+' then copied = val; return 0 end; return shipped_setreg(reg, val, ...) end

vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
local tab, ex
if not vim.wait(30000, function()
  tab = vim.api.nvim_get_current_tabpage(); ex = lc.get_explorer(tab); return ex and ex.tree and ex.winid
end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
vim.wait(2000, function() return false end, 50)

local line_of = {}
for line = 1, vim.api.nvim_buf_line_count(ex.bufnr) do
  local nd = ex.tree:get_node(line)
  local d = nd and nd.data or {}
  if d.type == 'directory' then line_of['dir:' .. (d.dir_path or d.path or '')] = line
  elseif d.path then line_of[d.path] = line end
end
if not line_of['aa/a1.txt'] then say('world=absent reason=file_row_absent'); return quit() end
local dir_key
for k in pairs(line_of) do if k:match('^dir:.*aa$') then dir_key = k end end
if not dir_key then say('world=absent reason=dir_row_absent (tree view?)'); return quit() end
say('world=present')

local keys = vim.api.nvim_replace_termcodes('<C-A-r>', true, false, true)
local function press(name, want)
  copied = nil
  vim.api.nvim_feedkeys(keys, 'mx', false)
  say(('%s=%s want=%s got=%s'):format(name, copied == want and 'hit' or 'miss', want, copied or '<none>'))
end

-- 1. a file row, 2. a directory row
vim.api.nvim_set_current_win(ex.winid)
vim.api.nvim_win_set_cursor(ex.winid, { line_of['aa/a1.txt'], 0 })
press('file_row', 'aa/a1.txt')
vim.api.nvim_win_set_cursor(ex.winid, { line_of[dir_key], 0 })
press('dir_row', 'aa')

-- 3. the revision side of a1's diff
vim.api.nvim_win_set_cursor(ex.winid, { line_of['aa/a1.txt'], 0 })
ex.on_file_select(ex.tree:get_node(line_of['aa/a1.txt']).data)
vim.wait(800, function() return false end, 20)
local sess = lc.get_session(tab)
local rev_win
for _, w in ipairs({ sess and sess.original_win, sess and sess.modified_win }) do
  if w and vim.api.nvim_win_is_valid(w) and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(w)):match('^codediff:') then rev_win = w end
end
if rev_win then
  vim.api.nvim_set_current_win(rev_win)
  say('rev_name=' .. vim.api.nvim_buf_get_name(0))
  press('rev_pane', 'aa/a1.txt')
else
  say('rev_pane=miss want=aa/a1.txt got=<no codediff: revision pane found>')
end

-- 4. an ordinary buffer, in a fresh tab
vim.cmd('tabnew ' .. vim.fn.fnameescape(root .. '/bb/b1.txt'))
press('plain_buf', 'bb/b1.txt')
quit()
