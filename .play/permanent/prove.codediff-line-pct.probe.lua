-- .what = drive :CodeDiff over a temp repo whose files each pin one case of the
--         line-change % (init.lua `cd_line_pct`), and read four facts off the
--         SHIPPED config:
--           1. each file row shows the % its diff earns
--           2. a refresh over no change asks git for no numstat and reads no file
--           3. an edit to ONE file re-asks numstat for that file alone, re-reads
--              that file alone, and moves that row's % alone
--           4. a staged file's % reads the INDEX side, never the work tree
--
-- .why  = the % must cost naught on the render path and naught on an idle
--         refresh: the explorer was tuned to stay quiet at ~1k diffs
--         (howto.tune-nvim-at-scale), and a numstat + a read of every file per
--         refresh would undo that
--
-- .the contract with its driver (`rhx nvim.test.headless --probe`)
--   PROBE_ARM  control | old-no-cache | old-off
--   PROBE_OUT  where to write the rows; never a fixed path
--
-- .the arms
--   control       the config as shipped
--   old-no-cache  the % cache wiped before each refresh → fact 2 must count asks
--   old-off       `_G.codediff_line_pct = false` → fact 1 must count no % rows
--   ⚠️ an old-* arm that reads like control is a defect in THIS probe: its
--      instrument cannot see the break it exists to catch (term=bite)
--
-- .the fixture, and the % each row must show
--   mod.txt     10 lines, 1 changed in the work tree   1+1 / (10+1)        = 18%
--   del.txt     4 lines, deleted from the work tree    0+4 / (0+4)         = 100%
--   new.txt     5 lines, untracked                     5 / 5               = 100%
--   stg.txt     10 lines; 5 changed and staged, then 10 appended unstaged
--                 staged:   5+5 / (index 10 + 5)                          = 67%
--                 unstaged: 10+0 / (work tree 20 + 0)                     = 50%
--   bin.dat     binary, changed                        no %
--   after the edit (fact 3): mod.txt gains a line      2+1 / (11+1)        = 25%
--
-- .the rows
--   world=<present|absent>
--   pct_rows=<file rows that show a %>
--   row=<group>:<path> pct=<shown|none>   (every file row)
--   expect_ok=<rows whose % matched the table above>/<rows judged>
--   noop_numstats=<git diff calls> noop_reads=<files opened>   (fact 2)
--   edit_numstats=<n> edit_numstat_paths=<paths on that call> edit_reads=<n>
--     edit_rows_moved=<rows whose % changed> mod_after=<%>     (fact 3)

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

-- the fixture
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
local function lines_n(n, tag)
  local t = {}
  for i = 1, n do t[i] = tag .. ' ' .. i end
  return t
end
local function put(name, lines) vim.fn.writefile(lines, root .. '/' .. name) end
sh('git init -q && git config user.email p@p && git config user.name p')
put('mod.txt', lines_n(10, 'mod'))
put('del.txt', lines_n(4, 'del'))
put('stg.txt', lines_n(10, 'stg'))
sh("printf 'a\\0b\\0c' > bin.dat")
sh('git add -A && git commit -qm init')
-- mod.txt: one line changed
local mod = lines_n(10, 'mod'); mod[3] = 'changed'; put('mod.txt', mod)
-- del.txt: gone from the work tree
vim.fn.delete(root .. '/del.txt')
-- new.txt: untracked
put('new.txt', lines_n(5, 'new'))
-- stg.txt: 5 lines changed and staged, then 10 more appended and left unstaged
local stg = lines_n(10, 'stg')
for i = 1, 5 do stg[i] = 'staged ' .. i end
put('stg.txt', stg)
sh('git add stg.txt')
vim.list_extend(stg, lines_n(10, 'tail'))
put('stg.txt', stg)
-- bin.dat: binary, changed
sh("printf 'a\\0b\\0d' > bin.dat")

local dirty = tonumber((sh('git status --porcelain | wc -l'):gsub('%s', ''))) or -1
if dirty ~= 5 then
  say(('world=absent dirty=%d'):format(dirty))
  return quit()
end
say('world=present')
vim.cmd('cd ' .. vim.fn.fnameescape(root))
if arm == 'old-off' then _G.codediff_line_pct = false end

-- wait on the overrides themselves, never a clock
pcall(require, 'codediff')
local function ours(mod_name, key)
  local ok, m = pcall(require, mod_name)
  return ok and type(m[key]) == 'function' and (debug.getinfo(m[key], 'S').source or ''):find('init%.lua$') ~= nil
end
if not vim.wait(20000, function()
  return ours('codediff.ui.explorer.nodes', 'prepare_node') and ours('codediff.ui.explorer.refresh', 'refresh')
    and type(_G.codediff_line_pct_state) == 'table'
end, 20) then
  say('world=absent reason=line_pct_never_installed')
  return quit()
end

-- count numstat asks (and their pathspecs) and file opens, from the moment they matter
local numstats, numstat_paths, reads = 0, {}, 0
local shipped_system = vim.system
vim.system = function(cmd, ...)
  if type(cmd) == 'table' and vim.tbl_contains(cmd, '--numstat') then
    numstats = numstats + 1
    local after = false
    for _, a in ipairs(cmd) do
      if after then numstat_paths[#numstat_paths + 1] = a end
      if a == '--' then after = true end
    end
  end
  return shipped_system(cmd, ...)
end
local shipped_open = vim.uv.fs_open
vim.uv.fs_open = function(path, ...)
  if type(path) == 'string' and path:find(root, 1, true) == 1 then reads = reads + 1 end
  return shipped_open(path, ...)
end
local function reset() numstats, numstat_paths, reads = 0, {}, 0 end

vim.cmd('CodeDiff')
local function explorer()
  local lc = require('codediff.ui.lifecycle')
  return lc.get_explorer and lc.get_explorer(vim.api.nvim_get_current_tabpage())
end
if not vim.wait(30000, function() local e = explorer(); return e and e.tree and e.bufnr end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
local ex = explorer()

-- settled = no pass in flight, and none queued, for a quiet stretch
local function settle()
  local function idle()
    local st = _G.codediff_line_pct_state.roots[ex.git_root]
    return not st or (not st.busy and next(st.queued) == nil)
  end
  vim.wait(10000, idle, 10)
  vim.wait(400, function() return false end, 20)
  vim.wait(10000, idle, 10)
end
settle()

-- read every file row off the explorer buffer: group:path → shown %
local function read_rows()
  local got, n = {}, 0
  for i = 1, vim.api.nvim_buf_line_count(ex.bufnr) do
    local nd = ex.tree:get_node(i)
    local d = nd and nd.data
    if d and d.path and d.type ~= 'directory' and d.type ~= 'group' then
      local text = vim.api.nvim_buf_get_lines(ex.bufnr, i - 1, i, false)[1] or ''
      local pct = text:match('(%d+%%)%s+%S+%s*$')
      got[d.group .. ':' .. d.path] = pct or 'none'
      if pct then n = n + 1 end
    end
  end
  return got, n
end

-- fact 1 + 4: the % each row shows
local want = {
  ['unstaged:mod.txt'] = '18%', ['unstaged:del.txt'] = '100%', ['unstaged:new.txt'] = '100%',
  ['unstaged:stg.txt'] = '50%', ['staged:stg.txt'] = '67%', ['unstaged:bin.dat'] = 'none',
}
local got, pct_rows = read_rows()
say(('pct_rows=%d'):format(pct_rows))
local keys = vim.tbl_keys(got)
table.sort(keys)
for _, k in ipairs(keys) do say(('row=%s pct=%s'):format(k, got[k])) end
local ok_n, judged = 0, 0
for k, w in pairs(want) do
  judged = judged + 1
  if got[k] == w then ok_n = ok_n + 1 else say(('expect_miss=%s want=%s got=%s'):format(k, w, tostring(got[k]))) end
end
say(('expect_ok=%d/%d'):format(ok_n, judged))

-- one refresh, settled by the seq init.lua's refresh bumps, then the % pass
local refresh_mod = require('codediff.ui.explorer.refresh')
local function one_refresh()
  if arm == 'old-no-cache' then _G.codediff_line_pct_state.roots = {} end
  local seq = ex.__cd_refresh_seq or 0
  refresh_mod.refresh(ex)
  local done = vim.wait(10000, function() return (ex.__cd_refresh_seq or 0) > seq end, 10)
  settle()
  return done
end

-- fact 2: a refresh over no change
reset()
if not one_refresh() then
  say('world=absent reason=refresh_never_settled')
  return quit()
end
say(('noop_numstats=%d noop_reads=%d'):format(numstats, reads))

-- fact 3: one file edited — mod.txt gains a line
local before = read_rows()
mod[#mod + 1] = 'one more'
put('mod.txt', mod)
reset()
if not one_refresh() then
  say('world=absent reason=edit_refresh_never_settled')
  return quit()
end
local after = read_rows()
local moved = 0
for k, v in pairs(after) do if before[k] ~= v then moved = moved + 1 end end
say(('edit_numstats=%d edit_numstat_paths=%s edit_reads=%d edit_rows_moved=%d mod_after=%s')
  :format(numstats, table.concat(numstat_paths, ','), reads, moved, tostring(after['unstaged:mod.txt'])))

vim.system = shipped_system
vim.uv.fs_open = shipped_open
quit()
