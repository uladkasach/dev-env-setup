-- .what = drive :CodeDiff over a temp repo with many changed files and read
--         five facts off the SHIPPED config:
--           1. an idle explorer does not refresh itself
--           2. a refresh that finds no change rebuilds no tree and rewrites no row;
--              forced to rebuild anyway, it still rewrites no row
--           3. a file select rewrites exactly the two rows whose highlight moved
--           4. a dir the human collapsed stays collapsed across a refresh
--           5. every row the shipped prepare_node builds equals upstream's row
--
-- .why  = each fact was a measured defect, and each froze the editor at ~1k
--         diffs (howto.tune-nvim-at-scale):
--           1. a background `git status` takes `.git/index.lock`; codediff
--              watches `.git/`, so each status woke the watcher for the next.
--              36 refreshes in 20 idle seconds at 1000 files
--           2 + 3. codediff's Tree:render rewrote EVERY row on every call —
--              ~100-200ms at 1000 files — and a select calls it just to move
--              the highlight
--           2. codediff refreshes on each BufEnter of the explorer, and rebuilt
--              the whole tree for an unchanged file list: 160ms build + 123ms
--              render at 6,475 files, ~2s after the explorer was usable
--           4. a restore moved BEFORE the render must still land (reported only)
--           5. init.lua's prepare_node hands upstream a basename proxy in tree
--              view (upstream's `([^/]+)$` match is quadratic on long paths),
--              decides `selected` itself, and memoizes rows. each is a place
--              to render a row upstream would not. the fixture's paths are long
--              and 8 dirs deep so the basename proxy is what gets exercised
--
-- .the contract with its driver (`rhx nvim.test.headless --probe`)
--   PROBE_ARM  control | old-locks | old-noop-rebuild | old-full-render | old-wrong-row
--   PROBE_OUT  where to write the rows; never a fixed path
--
-- .the arms
--   control          the config as shipped
--   old-locks        GIT_OPTIONAL_LOCKS unset after boot → the loop must show
--   old-noop-rebuild the no-change short-circuit off (`_G.codediff_skip_noop_refresh
--                    = false`) → the plain refresh must rebuild the tree
--   old-full-render  the row cache dropped before each render → every row rewritten
--   old-wrong-row    prepare_node swapped for one that bends the first segment's
--                    hl on file rows → fact 5 must count mismatches
--   ⚠️ an old-* arm that reads like control is a defect in THIS probe: its
--      instrument cannot see the break it exists to catch (term=bite)
--
-- 🟡 fact 4 is REPORTED, and gates no arm. measured 2026-10-07: with our restore
--    disabled, codediff's own restore still kept the dir collapsed in this
--    fixture, so no arm here can turn that row red. our restore exists for the
--    staged/unstaged path collision, which this fixture does not build
--
-- .the rows
--   world=<present|absent> n=<files> dirty=<git status lines>
--   idle_refreshes=<count over the idle window>
--   builds_per_noop_refresh=<create_tree_data calls in one refresh with no change>
--     rows_per_noop_refresh=<explorer rows that refresh wrote>
--   builds_per_noop_rebuild=<the same, short-circuit forced off>
--     rows_per_noop_rebuild=<explorer rows that forced rebuild wrote>
--   rows_per_select=<explorer rows written by one file select> select_ms=<sync cost>
--   collapsed_after_refresh=<true|false> dir=<path>
--   rows_match_upstream=<matched>/<compared> mismatches=<n> selected_compared=<n> width=<cols>
--   mismatch=<path> sel=<live|self|none> got=<content> want=<content> got_segs=<..> want_segs=<..>
--     (the first 3 only)
--
-- .fact 5's comparison: every node in the tree (groups, dirs, files), at the
--   explorer's real width, once under the live selection; each file row also
--   once as selected (its own path + group) and once unselected. content AND
--   the segment list (text + hl per segment) must both agree

local out = os.getenv('PROBE_OUT')
if not out then
  io.stderr:write('probe: PROBE_OUT is unset; it refuses to pick a path\n')
  os.exit(1)
end
-- the probe cds into its fixture, so a relative PROBE_OUT would land inside it
out = vim.fn.fnamemodify(out, ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local N, IDLE_MS = 200, 10000
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end
local function now() return vim.uv.hrtime() / 1e6 end

-- the fixture: N committed files, then every one modified
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
sh('git init -q && git config user.email p@p && git config user.name p')
-- long, 8-deep paths: the shape that made upstream's basename match quadratic
local function path_of(i)
  return ('%s/corpus=lot-enrichment/data/x-g%d/sales/sale-%08x/region-%d-northwest-territory/batch-archive-2026-q%d/record-%04d-lot-enrichment-sale-ledger-entry.txt')
    :format(root, i % 3, (i % 10) * 2654435761 % 4294967296, i % 4, i % 2, i)
end
for i = 1, N do
  vim.fn.mkdir(vim.fn.fnamemodify(path_of(i), ':h'), 'p')
  vim.fn.writefile({ 'line ' .. i, 'b' }, path_of(i))
end
sh('git add -A && git commit -qm init')
for i = 1, N do vim.fn.writefile({ 'line ' .. i, 'changed' }, path_of(i)) end
local dirty = tonumber((sh('git status --porcelain | wc -l'):gsub('%s', ''))) or -1
if dirty ~= N then
  say(('world=absent n=%d dirty=%d'):format(N, dirty))
  return quit()
end
say(('world=present n=%d dirty=%d'):format(N, dirty))
vim.cmd('cd ' .. vim.fn.fnameescape(root))

if arm == 'old-locks' then vim.env.GIT_OPTIONAL_LOCKS = nil end

-- wait on the OVERRIDES themselves, never a clock: they land inside codediff's
-- lazy config after a defer
pcall(require, 'codediff')
local function ours(mod, key)
  local ok, m = pcall(require, mod)
  return ok and type(m[key]) == 'function' and (debug.getinfo(m[key], 'S').source or ''):find('init%.lua$') ~= nil
end
if not vim.wait(20000, function()
  return ours('codediff.ui.lib.tree', 'render') and ours('codediff.ui.explorer.nodes', 'prepare_node')
end, 20) then
  say('world=absent reason=render_override_never_installed')
  return quit()
end

local Tree = require('codediff.ui.lib.tree')
local shipped_render = Tree.render
local renders = 0
Tree.render = function(self)
  renders = renders + 1
  if arm == 'old-full-render' then self.__cd_rows = nil end
  return shipped_render(self)
end

local refresh_mod = require('codediff.ui.explorer.refresh')
local refreshes = 0
local shipped_refresh = refresh_mod.refresh
refresh_mod.refresh = function(...) refreshes = refreshes + 1; return shipped_refresh(...) end

vim.cmd('CodeDiff')
local function explorer()
  local lc = require('codediff.ui.lifecycle')
  return lc.get_explorer and lc.get_explorer(vim.api.nvim_get_current_tabpage())
end
if not vim.wait(30000, function() local e = explorer(); return e and e.tree and e.bufnr end, 20) then
  say('world=absent reason=explorer_never_opened')
  return quit()
end
vim.wait(3000, function() return false end, 50) -- let the first-open work settle

-- fact 1: an idle window with no input
local before = refreshes
vim.wait(IDLE_MS, function() return false end, 100)
say(('idle_refreshes=%d window_ms=%d'):format(refreshes - before, IDLE_MS))

-- count explorer ROWS written, from here on
local ex = explorer()
local written = 0
local set_lines = vim.api.nvim_buf_set_lines
vim.api.nvim_buf_set_lines = function(buf, s, e, strict, lines)
  if buf == ex.bufnr then written = written + #lines end
  return set_lines(buf, s, e, strict, lines)
end

-- fact 2 (+4): collapse one leaf dir, render, then one refresh that finds no change
-- a tree-view dir carries `dir_path`, never `path`. take the LAST dir by path:
-- a leaf dir, so its collapse hides a few files; the first dir by path is the
-- root every file sits under, and its collapse would hide them all
local function dir_of(nd) return nd.data.dir_path or nd.data.path or '' end
local target
for _, nd in pairs(ex.tree._nodes_by_id) do
  if nd.data and nd.data.type == 'directory' and (not target or dir_of(nd) > dir_of(target)) then target = nd end
end
if not target then
  say('world=absent reason=no_directory_node')
  return quit()
end
local tpath = dir_of(target)
target:collapse()
ex.tree:render()

-- one refresh, judged by the seq init.lua's refresh bumps once it settles — never by
-- a render, since a no-change refresh is meant to render naught
local tree_mod = require('codediff.ui.explorer.tree')
local builds = 0
local shipped_build = tree_mod.create_tree_data
tree_mod.create_tree_data = function(...)
  builds = builds + 1
  return shipped_build(...)
end
local function one_refresh(skip)
  _G.codediff_skip_noop_refresh = skip
  written, builds = 0, 0
  local seq = ex.__cd_refresh_seq or 0
  refresh_mod.refresh(ex)
  local ok = vim.wait(10000, function() return (ex.__cd_refresh_seq or 0) > seq end, 10)
  vim.wait(300, function() return false end, 10)
  return ok
end

-- fact 2a: the refresh as shipped, over no change: no rebuild, no row
if not one_refresh(arm ~= 'old-noop-rebuild') then
  say('world=absent reason=refresh_never_settled')
  return quit()
end
say(('builds_per_noop_refresh=%d rows_per_noop_refresh=%d'):format(builds, written))
-- fact 2b: a FORCED rebuild over no change still rewrites no row (the row diff)
if not one_refresh(false) then
  say('world=absent reason=rebuild_never_settled')
  return quit()
end
say(('builds_per_noop_rebuild=%d rows_per_noop_rebuild=%d'):format(builds, written))
_G.codediff_skip_noop_refresh = true

-- fact 3: select one VISIBLE file, then measure the select of a second one, so
-- both the old and the new highlighted rows are on screen
local files = {}
for i = 1, vim.api.nvim_buf_line_count(ex.bufnr) do
  local nd = ex.tree:get_node(i)
  if nd and nd.data and nd.data.path and nd.data.type ~= 'directory' and nd.data.type ~= 'group' then
    files[#files + 1] = nd
    if #files == 2 then break end
  end
end
if #files < 2 then
  say('world=absent reason=fewer_than_two_visible_files')
  return quit()
end
ex.on_file_select(files[1].data)
vim.wait(300, function() return false end, 10)
local pick = files[2]
written = 0
local t0 = now()
ex.on_file_select(pick.data)
local select_ms = now() - t0
say(('rows_per_select=%d select_ms=%.0f'):format(written, select_ms))

vim.api.nvim_buf_set_lines = set_lines
local collapsed
for _, nd in pairs(ex.tree._nodes_by_id) do
  if nd.data and nd.data.type == 'directory' and dir_of(nd) == tpath then collapsed = not nd:is_expanded() end
end
say(('collapsed_after_refresh=%s dir=%s'):format(collapsed == nil and 'absent' or (collapsed and 'true' or 'false'), tpath))

-- fact 5: the shipped prepare_node against upstream's, row by row
local nodes_mod = require('codediff.ui.explorer.nodes')
local upstream = _G.codediff_prepare_upstream
if type(upstream) ~= 'function' then
  say('world=absent reason=upstream_prepare_not_exposed')
  return quit()
end
if arm == 'old-wrong-row' then
  -- a NEW Line, so the bend never leaks into the shipped memo
  local Line = require('codediff.ui.lib.line')
  local shipped_prepare = nodes_mod.prepare_node
  nodes_mod.prepare_node = function(node, ...)
    local line = shipped_prepare(node, ...)
    local d = node.data or {}
    if d.type == 'group' or d.type == 'directory' or not d.path then return line end
    local bent = Line()
    for k, seg in ipairs(line._segments) do bent:append(seg.text, k == 1 and 'CodeDiffProbeBent' or seg.hl) end
    return bent
  end
end
local function segs_of(line)
  local parts = {}
  for k, seg in ipairs(line._segments) do parts[k] = ('[%s|%s]'):format(seg.text, seg.hl or 'nil') end
  return table.concat(parts)
end
local width = vim.api.nvim_win_get_width(ex.winid or vim.fn.bufwinid(ex.bufnr))
local sel_path, sel_group = ex.current_file_path, ex.current_file_group
local compared, matched, sel_compared, bad = 0, 0, 0, {}
local function compare(nd, sp, sg, tag)
  compared = compared + 1
  local d = nd.data or {}
  if d.path and d.path == sp and d.group == sg then sel_compared = sel_compared + 1 end
  local got = nodes_mod.prepare_node(nd, width, sp, sg)
  local want = upstream(nd, width, sp, sg)
  local gc, wc, gs, ws = got:content(), want:content(), segs_of(got), segs_of(want)
  if gc == wc and gs == ws then
    matched = matched + 1
    return
  end
  bad[#bad + 1] = ('mismatch=%s sel=%s got=%q want=%q got_segs=%s want_segs=%s')
    :format(d.path or d.dir_path or nd.text or '?', tag, gc, wc, gs, ws)
end
for _, nd in pairs(ex.tree._nodes_by_id) do
  local d = nd.data or {}
  compare(nd, sel_path, sel_group, 'live')
  if d.path and d.type ~= 'group' and d.type ~= 'directory' then
    compare(nd, d.path, d.group, 'self')
    compare(nd, nil, nil, 'none')
  end
end
say(('rows_match_upstream=%d/%d mismatches=%d selected_compared=%d width=%d')
  :format(matched, compared, #bad, sel_compared, width))
for k = 1, math.min(3, #bad) do say(bad[k]) end
quit()
