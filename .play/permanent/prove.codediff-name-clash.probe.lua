-- .what = drive codediff's explorer tree build over a path that is BOTH a file and
--         a folder in one change set — the shape a dir-turned-symlink produces:
--           A  .claude                  (the symlink, a file entry)
--           R  .claude/settings.json    (a path inside the old folder)
--
-- .why  = init.lua overrides `codediff.ui.explorer.nodes.create_tree_file_nodes`.
--         its walk kept one node per name, so file-first crashed on
--         `attempt to index local 'current' (a nil value)` and folder-first hid the
--         folder. this probe is the clamp: it goes red on that code and green on
--         the fix (`rule.require.clamp-edge-cases`)
--
-- .the contract with its driver (`rhx nvim.test.headless --probe`)
--   PROBE_ARM  the arm name — which config was booted is the DRIVER's `--config`
--   PROBE_OUT  where to write the rows; never a fixed path
--
-- .the rows, one per order
--   order=<file-first|folder-first> ok=<true|false> tops=<top-level node texts>
--   the fix reads `ok=true tops=.claude,.claude (file)` for BOTH orders
--
-- 🛑 .it waits on the OVERRIDE ITSELF, never a clock
--   - the override lands inside codediff's lazy config, after a 50ms defer
--   - ⇒ `ready` holds once `create_tree_file_nodes` is the function DEFINED IN
--     init.lua, per `debug.getinfo`. that is the question, not a proxy for it,
--     and it holds for any init.lua a `--config` boots
--   - the 20s is a BOUND on the hang; it writes `world=absent`, never a verdict

local out = os.getenv('PROBE_OUT')
if not out then
  io.stderr:write('probe: PROBE_OUT is unset; it refuses to pick a path\n')
  os.exit(1)
end
local function say(rows) vim.fn.writefile(rows, out) end

-- trigger the lazy load; lazy.nvim loads a plugin on the first require of its module
pcall(require, 'codediff')

local function ready()
  local ok, nodes = pcall(require, 'codediff.ui.explorer.nodes')
  if not ok or type(nodes.create_tree_file_nodes) ~= 'function' then return false end
  local src = debug.getinfo(nodes.create_tree_file_nodes, 'S').source or ''
  return src:find('init%.lua$') ~= nil
end

if not vim.wait(20000, ready, 50) then
  say({ 'world=absent reason=override_never_installed' })
  vim.cmd('qa!')
  return
end

local nodes = require('codediff.ui.explorer.nodes')
local file_entry = { path = '.claude', status = 'A' }
local folder_entry = { path = '.claude/settings.json', status = 'R', old_path = '.claude/settings.old.json' }

local function drive(name, files)
  local ok, result = pcall(nodes.create_tree_file_nodes, files, '/probe/root', 'unstaged')
  if not ok then
    return ('order=%s ok=false error=%s'):format(name, tostring(result):gsub('\n', ' '))
  end
  local tops = {}
  for _, node in ipairs(result) do tops[#tops + 1] = node.text end
  table.sort(tops)
  return ('order=%s ok=true tops=%s'):format(name, table.concat(tops, ','))
end

say({
  'world=present',
  drive('file-first', { file_entry, folder_entry }),
  drive('folder-first', { folder_entry, file_entry }),
  -- a path with no segments must be skipped, never indexed as `current[nil]`
  drive('empty-path', { { path = '', status = 'M' }, file_entry }),
})
vim.cmd('qa!')
