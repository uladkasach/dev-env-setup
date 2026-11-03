-- .what = drive :CodeDiff over a temp repo with one modified, one deleted, and one
--         untracked file, and select them in the order that killed the view:
--           untracked → deleted → modified
--         then read two facts off the SHIPPED config:
--           1. after the deleted select, the diff session is still alive
--           2. after the modified select, both diff panes are live windows
--
-- .why  = codediff shows a deleted / added / untracked file in ONE pane. a mix of
--         such selects must never lose the diff view: no torn-down session, and a
--         later modified file back in two panes
--
-- .the contract with its driver (`rhx nvim.test.headless --probe`)
--   PROBE_ARM  control | forced-teardown
--   PROBE_OUT  where to write the rows; never a fixed path
--
-- .the arms
--   control          the config as shipped: codediff's own show_* functions
--   forced-teardown  after the deleted select, both diff panes are closed — the end
--                    state codediff 2.41.1 reached on its own
--                    → the session must read dead. if it reads alive, this probe
--                      cannot see a lost view, and control's green proves naught
--                      (term=bite)
--
-- .the rows
--   world=<present|absent> [reason=...]
--   session_after_deleted=<alive|dead>
--   panes_after_modified=<0|1|2> session_after_modified=<alive|dead>

local out = os.getenv('PROBE_OUT')
if not out then
  io.stderr:write('probe: PROBE_OUT is unset; it refuses to pick a path\n')
  os.exit(1)
end
out = vim.fn.fnamemodify(out, ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end

-- the fixture: three committed files, then one modified, one deleted, one untracked
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
sh('git init -q && git config user.email p@p && git config user.name p')
for _, f in ipairs({ 'mod.txt', 'del.txt', 'keep.txt' }) do vim.fn.writefile({ f, 'b' }, root .. '/' .. f) end
sh('git add -A && git commit -qm init')
vim.fn.writefile({ 'mod.txt', 'changed' }, root .. '/mod.txt')
vim.fn.delete(root .. '/del.txt')
vim.fn.writefile({ 'new' }, root .. '/new.txt')
local status = sh('git status --porcelain')
if not (status:find(' M mod.txt', 1, true) and status:find(' D del.txt', 1, true) and status:find('?? new.txt', 1, true)) then
  say('world=absent reason=fixture_status ' .. status:gsub('\n', ';'))
  return quit()
end
vim.cmd('cd ' .. vim.fn.fnameescape(root))

-- wait on the module the selects reach, never a clock: it loads inside codediff's lazy config
pcall(require, 'codediff')
local sbs
if not vim.wait(20000, function()
  local ok, mod = pcall(require, 'codediff.ui.view.side_by_side')
  sbs = ok and mod or nil
  return sbs ~= nil and type(sbs.show_deleted_file) == 'function'
end, 20) then
  say('world=absent reason=side_by_side_never_loaded')
  return quit()
end

vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
-- ⚠️ :CodeDiff opens a NEW tab, so the tab is read inside the wait, never before
local tab, ex
if not vim.wait(30000, function()
  tab = vim.api.nvim_get_current_tabpage()
  ex = lc.get_explorer and lc.get_explorer(tab)
  return ex and ex.tree and ex.bufnr
end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
vim.wait(1500, function() return false end, 50)

-- find each file node by path
local function node_of(path)
  for _, nd in pairs(ex.tree._nodes_by_id) do
    if nd.data and nd.data.path == path and nd.data.type ~= 'directory' and nd.data.type ~= 'group' then return nd end
  end
end
local nmod, ndel, nnew = node_of('mod.txt'), node_of('del.txt'), node_of('new.txt')
if not (nmod and ndel and nnew) then
  say(('world=absent reason=nodes_absent mod=%s del=%s new=%s'):format(tostring(nmod ~= nil), tostring(ndel ~= nil), tostring(nnew ~= nil)))
  return quit()
end
say('world=present')

local function settle() vim.wait(600, function() return false end, 20) end
local function alive() return lc.get_session(tab) ~= nil end

ex.on_file_select(nmod.data); settle()
if not alive() then
  say('world=absent reason=session_never_formed')
  return quit()
end
ex.on_file_select(nnew.data); settle()
ex.on_file_select(ndel.data); settle()
-- forced-teardown: close both diff panes, the end state of the 2.41.1 chain
if arm == 'forced-teardown' then
  local s = lc.get_session(tab)
  for _, w in ipairs({ s and s.original_win, s and s.modified_win }) do
    if w and vim.api.nvim_win_is_valid(w) then pcall(vim.api.nvim_win_close, w, true) end
  end
  settle()
end
say(('session_after_deleted=%s'):format(alive() and 'alive' or 'dead'))

ex.on_file_select(nmod.data); settle()
local panes = 0
local sess = lc.get_session(tab)
if sess then
  for _, w in ipairs({ sess.original_win, sess.modified_win }) do
    if w and vim.api.nvim_win_is_valid(w) then panes = panes + 1 end
  end
end
say(('panes_after_modified=%d session_after_modified=%s'):format(panes, sess and 'alive' or 'dead'))
quit()
