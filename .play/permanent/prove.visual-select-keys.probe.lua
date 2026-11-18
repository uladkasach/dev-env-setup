-- .what = drive the super+v gesture through the nvim overlay kitty opens when
--         no tmux holds the window (4.3.2.emulator/visual_select.py), against
--         the REAL init.lua, and read the mode, selection, and yank per press
--
-- .why  = the overlay's keys are buffer maps over a config that already binds a
--         global <CR> and a visual <C-c>; a buffer map that fails to outrank
--         them drops the press with no error
--
-- .the arms
--   control  the setup sourced, as visual_select.py sources it → every row hit
--   bare     no setup → enter must NOT begin a selection. if it does, the
--            probe cannot tell the setup from nvim's own keys
--
-- .the env
--   PROBE_ARM  control | bare
--   PROBE_OUT  where to write the rows; never a fixed path
--
-- ⚠️ headless nvim has no clipboard provider, so the yank is read off
--    TextYankPost, which fires for the register whatever the provider does
--
-- .rows written: world=…, then <row>=<hit|miss> want=<…> got=<…>

local out = os.getenv('PROBE_OUT')
if not out or out == '' then
  io.stderr:write('probe: PROBE_OUT is unset; it refuses to pick a path\n')
  vim.cmd('cq')
end
out = vim.fn.fnamemodify(out, ':p')
local arm = os.getenv('PROBE_ARM') or 'control'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function row(name, got, want)
  say(('%s=%s want=%s got=%s'):format(name, got == want and 'hit' or 'miss', want, got))
end

-- the setup under test: this checkout's copy, which the bundle verify holds
-- byte-equal to the one kitty deploys
local here = vim.fn.fnamemodify(debug.getinfo(1, 'S').source:sub(2), ':p:h')
local setup = here .. '/../../src/grove.provision/4.terminal/4.5.nvim/visual_select.lua'
if vim.fn.filereadable(setup) == 0 then
  say('world=absent reason=setup_not_found path=' .. setup)
  return vim.cmd('qa!')
end
if not _G.nvim_errorlog then
  say('world=absent reason=config_never_loaded')
  return vim.cmd('qa!')
end

-- the world: what `@screen_scrollback` hands nvim — history, then the blank
-- rows below the prompt
local lines = {}
for i = 1, 40 do lines[#lines + 1] = tostring(i) end
lines[#lines + 1] = ''
lines[#lines + 1] = ''
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
vim.bo.modified = false
say('world=present arm=' .. arm)

local yanked
vim.api.nvim_create_autocmd('TextYankPost', {
  callback = function() yanked = table.concat(vim.v.event.regcontents, ',') end,
})

if arm == 'control' then vim.cmd('source ' .. vim.fn.fnameescape(setup)) end

local function press(keys)
  vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(keys, true, false, true), 'mx', false)
end
local function mode() return vim.api.nvim_get_mode().mode end

if arm == 'control' then
  row('opens_on_last_text', tostring(vim.fn.line('.')), '40')
  row('a_view_not_a_file', vim.bo.buftype, 'nofile')
  -- ⚠️ the view's width (no minimap, no gutter) is NOT read here: a headless
  --    nvim draws neither even without the setup, so a row here could not fail.
  --    prove.visual-select-overlay reads it off the screen a real kitty draws
end

press('<CR>')
local begun = mode() == 'V'
row('enter_begins', tostring(begun), arm == 'control' and 'true' or 'false')
if arm ~= 'control' then return vim.cmd('qa!') end

press('<Up>')
row('up_extends', vim.fn.line('v') .. '-' .. vim.fn.line('.'), '40-39')

press('<C-S-c>')
row('ctrl_c_copies', tostring(yanked), '39,40')
row('ctrl_c_keeps_selection', mode(), 'V')

press('<CR>')
row('enter_ends', mode(), 'n')

-- ctrl+x: the map is read rather than pressed, since a press ends the probe
local leave = vim.fn.maparg('<C-c>', 'n', false, true)
row('ctrl_x_leaves', tostring(leave.buffer == 1 and leave.rhs:match('qa!') ~= nil), 'true')
local leave_x = vim.fn.maparg('<C-c>', 'x', false, true)
row('ctrl_x_leaves_from_a_selection', tostring(leave_x.buffer == 1 and leave_x.rhs:match('qa!') ~= nil), 'true')
local leave_q = vim.fn.maparg('q', 'x', false, true)
row('q_leaves_from_a_selection', tostring(leave_q.buffer == 1 and leave_q.rhs:match('qa!') ~= nil), 'true')
local leave_esc = vim.fn.maparg('<Esc>', 'n', false, true)
row('esc_leaves', tostring(leave_esc.buffer == 1 and leave_esc.rhs:match('qa!') ~= nil), 'true')
local leave_esc_x = vim.fn.maparg('<Esc>', 'x', false, true)
row('esc_leaves_from_a_selection', tostring(leave_esc_x.buffer == 1 and leave_esc_x.rhs:match('qa!') ~= nil), 'true')
local leave_c = vim.fn.maparg('<C-S-c>', 'n', false, true)
row('ctrl_c_with_no_selection_leaves', tostring(leave_c.buffer == 1 and leave_c.rhs:match('qa!') ~= nil), 'true')

vim.cmd('qa!')
