-- .what = drive the super+v gesture through the nvim overlay kitty opens when
--         no tmux holds the window (4.3.2.emulator/visual_select.py), against
--         the REAL init.lua, and read the mode, selection, and yank per press
--
-- .why  = the view is plain vim plus ONE addition, the ctrl+d k / j command
--         jumps. a buffer map that fails to outrank init.lua's global <C-d>
--         chords drops the press with no error; a leftover map would make a
--         stock key (enter, escape, q) do aught but what vim does
--
-- .the arms
--   control  the setup sourced, as visual_select.py sources it → every row hit
--   bare     no setup → ctrl+d k must NOT land on a prompt. if it does, the
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

-- the world: what `@screen_scrollback` hands nvim — history with two starship
-- prompts in it (a bare `➜`, and one led by a status glyph), then the blank
-- rows below the prompt
local lines = {}
for i = 1, 40 do lines[#lines + 1] = tostring(i) end
lines[10] = '➜ echo one'
lines[30] = '💥1 ➜ echo two'
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

-- the discriminator first: in a selection from the last line, ctrl+d k lands on
-- the prompt at 30 with the setup, and anywhere else without it
press('V')
press('<C-d>k')
local landed = vim.fn.line('.')
press('<Esc>')
row('ctrl_d_k_reaches_the_prompt', tostring(landed == 30), arm == 'control' and 'true' or 'false')
if arm ~= 'control' then return vim.cmd('qa!') end

-- plain vim: shift+v selects, k extends, ctrl+c copies as init.lua's visual map does
vim.cmd('normal! G')
vim.fn.search('\\S', 'bcW')
press('V')
row('shift_v_begins', mode(), 'V')
press('k')
row('k_extends', vim.fn.line('v') .. '-' .. vim.fn.line('.'), '40-39')
press('<C-S-c>')
row('ctrl_c_copies', tostring(yanked), '39,40')
row('ctrl_c_ends_as_y_does', mode(), 'n')

-- command jumps grow a selection by whole commands, and move in normal mode too
vim.cmd('normal! G')
vim.fn.search('\\S', 'bcW')
press('V')
press('<C-d>k')
row('ctrl_d_k_selects_to_the_command', vim.fn.line('v') .. '-' .. vim.fn.line('.'), '40-30')
press('<C-d>k')
row('ctrl_d_k_again_reaches_the_prior', tostring(vim.fn.line('.')), '10')
press('<C-d>k')
row('ctrl_d_k_stops_at_the_first', tostring(vim.fn.line('.')), '10')
press('<C-d>j')
row('ctrl_d_j_reaches_the_next', tostring(vim.fn.line('.')), '30')
row('the_selection_holds', mode(), 'V')
press('<Esc>')
press('<C-d><C-k>')
row('ctrl_held_ctrl_d_k_in_normal', tostring(vim.fn.line('.')), '10')
press('<C-d><CR>')
row('ctrl_held_ctrl_d_j_through_tmux', tostring(vim.fn.line('.')), '30')

-- no stock key is overridden: enter, escape, q, and ctrl+c are vim's own here
for _, k in ipairs({ { '<CR>', 'n' }, { '<CR>', 'x' }, { '<Esc>', 'n' }, { '<Esc>', 'x' },
                     { 'q', 'n' }, { 'q', 'x' }, { '<C-c>', 'x' }, { '<C-S-c>', 'x' } }) do
  local m = vim.fn.maparg(k[1], k[2], false, true)
  row('stock_' .. k[2] .. '_' .. k[1]:gsub('[<>]', ''), tostring(m.buffer == 1), 'false')
end

vim.cmd('qa!')
