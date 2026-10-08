-- .what = in the codediff explorer, press ctrl+d j / ctrl+d k from the first file of
--         a directory and read where the cursor lands, against the rows the tree
--         says each step owes (criteria: diff.boundary.nav, usecase.5)
--
-- .fixture = two dirs, `aa/` with 3 changed files and `bb/` with 2. in tree view:
--     aa/            ← top of block A
--       a1  ← start here
--       a2
--       a3           ← bottom of block A
--     bb/            ← top of block B
--       b1
--       b2           ← bottom of block B
--
-- .the presses and what each owes
--   j_bot   <C-d>j from a1          → a3   (bottom of the current directory)
--   j_next  <C-d>j from a3          → bb/  (top of the next directory)
--   k_prev  <C-d>k from bb/         → a3   (bottom of the previous directory)
--   k_top   <C-d>k from a3          → aa/  (top of the current directory)
--   j_wrap  <C-d>j from b2          → aa/  (wraps to the first directory)
--
-- .the arms
--   control       as shipped → every row reads hit
--   old-chunks    `_G.codediff_explorer_dir_nav = false` → the diff-chunk reader in
--                 the explorer finds no chunk, so j_bot reads miss (term=bite)
--
-- .the rows
--   world=<present|absent>
--   <press>=<hit|miss> want=<line> got=<line>

local out = vim.fn.fnamemodify(os.getenv('PROBE_OUT'), ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end

local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/aa', 'p'); vim.fn.mkdir(root .. '/bb', 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
sh('git init -q && git config user.email p@p && git config user.name p')
local files = { 'aa/a1.txt', 'aa/a2.txt', 'aa/a3.txt', 'bb/b1.txt', 'bb/b2.txt' }
for _, f in ipairs(files) do vim.fn.writefile({ 'x' }, root .. '/' .. f) end
sh('git add -A && git commit -qm init')
for _, f in ipairs(files) do vim.fn.writefile({ 'y' }, root .. '/' .. f) end
vim.cmd('cd ' .. vim.fn.fnameescape(root))

pcall(require, 'codediff')
if not vim.wait(20000, function() return _G.codediff_resize_debounce_ms ~= nil end, 20) then
  say('world=absent reason=config_never_loaded')
  return quit()
end
if arm == 'old-chunks' then _G.codediff_explorer_dir_nav = false end

vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
local ex
if not vim.wait(30000, function() ex = lc.get_explorer(vim.api.nvim_get_current_tabpage()); return ex and ex.tree and ex.winid end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
vim.wait(2000, function() return false end, 50)

-- the line of each row, read off the tree
local line_of = {}
for line = 1, vim.api.nvim_buf_line_count(ex.bufnr) do
  local nd = ex.tree:get_node(line)
  local d = nd and nd.data or {}
  if d.type == 'directory' then
    local p = (d.dir_path or d.path or ''):match('([^/]+)/?$')
    if p then line_of[p .. '/'] = line_of[p .. '/'] or line end
  elseif d.path then
    line_of[d.path] = line
  end
end
for _, k in ipairs({ 'aa/', 'bb/', 'aa/a1.txt', 'aa/a3.txt', 'bb/b2.txt' }) do
  if not line_of[k] then
    say('world=absent reason=row_absent row=' .. k .. ' (is the explorer in tree view?)')
    return quit()
  end
end
say('world=present')

-- focus the explorer through a BufEnter, so its buffer maps bind under this arm
local other = vim.api.nvim_list_wins()[1] == ex.winid and vim.api.nvim_list_wins()[2] or vim.api.nvim_list_wins()[1]
if other then vim.api.nvim_set_current_win(other) end
vim.api.nvim_set_current_win(ex.winid)

local function press(chord, from, want, name)
  vim.api.nvim_win_set_cursor(ex.winid, { line_of[from], 0 })
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(chord, true, false, true), 'mx', false)
  local got = vim.api.nvim_win_get_cursor(ex.winid)[1]
  say(('%s=%s want=%d got=%d'):format(name, got == line_of[want] and 'hit' or 'miss', line_of[want], got))
end
press('<C-d>j', 'aa/a1.txt', 'aa/a3.txt', 'j_bot')
press('<C-d>j', 'aa/a3.txt', 'bb/', 'j_next')
press('<C-d>k', 'bb/', 'aa/a3.txt', 'k_prev')
press('<C-d>k', 'aa/a3.txt', 'aa/', 'k_top')
press('<C-d>j', 'bb/b2.txt', 'aa/', 'j_wrap')
quit()
