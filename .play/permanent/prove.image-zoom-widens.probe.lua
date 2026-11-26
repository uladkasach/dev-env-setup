-- .what = zoom a TALL image diff step by step, and read the footprint each step paints
--
-- .the world
--   a git repo whose cc/page.png changes: a 260x1173 page, the shape of a long invoice
--   screenshot. codediff shows it as an image diff; its panes fit it by height, so
--   at 1x it is a thin column
--
-- .the claim (criteria: image diff zoom is a viewer zoom)
--   each ctrl+= step paints a WIDER footprint, until the page meets the pane edge;
--   no step paints wider than the pane; the top step fills the pane's width
--
-- ⚠️ headless nvim has no tty and no pixel size, so the probe stands in a no-op tty
--    and a fixed 10x20 cell. the crop and the reload are the REAL code paths, and the
--    footprint is read from :ImageDiffZoomReport — what image.nvim was handed to paint
--
-- .rows written: world=…, then step<N> rows, then the judgements

local out = vim.fn.fnamemodify(os.getenv('PROBE_OUT'), ':p')
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end

-- headless nvim has no tty on fd 1; the kitty module opens one at load
local new_tty_shipped = vim.loop.new_tty
vim.loop.new_tty = function(fd, readable)
  local tty = new_tty_shipped(fd, readable)
  if tty then return tty end
  return { write = function() end, close = function() end, is_closing = function() return false end }
end
for name in pairs(package.loaded) do
  if name:match('^image') then package.loaded[name] = nil end
end
pcall(function()
  local plugin = require('lazy.core.config').plugins['image.nvim']
  if plugin and plugin._.loaded then require('lazy.core.loader').reload(plugin)
  else require('lazy').load({ plugins = { 'image.nvim' } }) end
end)
local ok_t, term = pcall(require, 'image/utils/term')
if not ok_t then say('world=absent reason=image_nvim_not_loaded'); return quit() end
-- the size of the foreman tab this was measured on: 273x70 cells
vim.o.columns, vim.o.lines = 273, 70
local CELL_W, CELL_H = 10, 20
term.get_size = function()
  return { cell_width = CELL_W, cell_height = CELL_H, screen_cols = vim.o.columns, screen_rows = vim.o.lines,
    screen_x = vim.o.columns * CELL_W, screen_y = vim.o.lines * CELL_H }
end

-- the world: a tall page that changes between two commits
local root = vim.fn.tempname()
vim.fn.mkdir(root .. '/cc', 'p')
local function sh(cmd) return vim.fn.system({ 'bash', '-c', 'cd ' .. vim.fn.shellescape(root) .. ' && ' .. cmd }) end
local magick = vim.fn.executable('magick') == 1 and 'magick' or 'convert'
sh('git init -q && git config user.email p@p && git config user.name p')
sh(magick .. ' -size 260x1173 gradient:white-gray cc/page.png')
sh('git add -A && git commit -qm init')
sh(magick .. ' -size 260x1173 gradient:white-blue cc/page.png')
vim.cmd('cd ' .. vim.fn.fnameescape(root))

pcall(require, 'codediff')
if not vim.wait(20000, function() return _G.codediff_resize_debounce_ms ~= nil end, 20) then
  say('world=absent reason=config_never_loaded'); return quit()
end
vim.cmd('CodeDiff')
local lc = require('codediff.ui.lifecycle')
local tab, ex
if not vim.wait(30000, function()
  tab = vim.api.nvim_get_current_tabpage(); ex = lc.get_explorer(tab); return ex and ex.tree and ex.winid
end, 20) then say('world=absent reason=explorer_never_opened'); return quit() end
vim.wait(1500, function() return false end, 50)

local line
for l = 1, vim.api.nvim_buf_line_count(ex.bufnr) do
  local nd = ex.tree:get_node(l)
  if nd and nd.data and nd.data.path == 'cc/page.png' then line = l end
end
if not line then say('world=absent reason=no_page_row'); return quit() end
vim.api.nvim_set_current_win(ex.winid)
vim.api.nvim_win_set_cursor(ex.winid, { line, 0 })
ex.on_file_select(ex.tree:get_node(line).data)
vim.wait(2000, function() return false end, 20)

local function report()
  local ok, res = pcall(vim.api.nvim_exec2, 'ImageDiffZoomReport', { output = true })
  if not ok then return nil, tostring(res) end
  local panes = {}
  for l in res.output:gmatch('[^\n]+') do
    local win, zoom, w, h = l:match('^win=(%d+) zoom=(%S+)x .- painted_src=(%d+)x(%d+)')
    if win then panes[#panes + 1] = { win = tonumber(win), zoom = zoom, w = tonumber(w), h = tonumber(h) } end
  end
  return panes, res.output
end

local panes, raw = report()
if not panes or #panes == 0 then say('world=absent reason=no_zoom_panes ' .. tostring(raw):gsub('\n', ' | ')); return quit() end
local win = panes[#panes].win
local pane_cols = vim.api.nvim_win_get_width(win)
say(('world=present pane_cols=%d pane_rows=%d'):format(pane_cols, vim.api.nvim_win_get_height(win)))

-- every kitty transmit goes out through write_graphics with a transmit format;
-- a step or a pan that re-sends the picture shows up as a count
local wire = require('image/backends/kitty/' .. 'help' .. 'ers')
local sends = 0
local write_shipped = wire.write_graphics
wire.write_graphics = function(cfg, ...)
  if cfg and cfg.transmit_format then sends = sends + 1 end
  return write_shipped(cfg, ...)
end

-- step up through every zoom level; the footprint in cells is what image.nvim paints
-- an image at natural size: its pixels over the cell size, capped by the pane
local zoom_in = vim.api.nvim_replace_termcodes('<C-=>', true, false, true)
local widths = {}
local sends_first_zoom
for step = 1, 7 do
  if step > 1 then
    vim.api.nvim_feedkeys(zoom_in, 'mx', false)
    vim.wait(300, function() return false end, 20)
  end
  local ps = report()
  local p
  for _, q in ipairs(ps or {}) do if q.win == win then p = q end end
  if not p then say(('step%d=absent'):format(step)); break end
  local cols = math.min(pane_cols, math.floor(p.w / CELL_W))
  widths[#widths + 1] = cols
  say(('step%d zoom=%sx painted_src=%dx%d cols=%d'):format(step, p.zoom, p.w, p.h, cols))
  if step == 2 then sends_first_zoom = sends end
end
local sends_later_steps = sends - (sends_first_zoom or sends)
say(('zoom sends: first_step=%d later_steps=%d'):format(sends_first_zoom or -1, sends_later_steps))

-- the judgements
local widens = #widths == 7 and widths[2] > widths[1] and widths[3] > widths[2]
local never_shrinks, within = true, true
for i = 2, #widths do if widths[i] < widths[i - 1] then never_shrinks = false end end
for _, c in ipairs(widths) do if c > pane_cols then within = false end end
say(('widens=%s'):format(widens and 'hit' or 'miss'))
say(('never_shrinks=%s'):format(never_shrinks and 'hit' or 'miss'))
say(('within_pane=%s'):format(within and 'hit' or 'miss'))
say(('fills_width=%s'):format((widths[#widths] or 0) >= pane_cols - 1 and 'hit' or 'miss'))
say(('zoom_steps_send_none=%s'):format(sends_later_steps == 0 and 'hit' or 'miss'))

-- the pan: at the top zoom, j/k and the wheel move the view, and send NO picture
sends = 0
local function center_and_band()
  local _, out = report()
  for l in tostring(out):gmatch('[^\n]+') do
    local w, cy, band = l:match('^win=(%d+) .- center=%S-,(%S+) .- band=(%S+)')
    if tonumber(w) == win then return tonumber(cy), band end
  end
end
local cy0, band0 = center_and_band()
vim.api.nvim_set_current_win(win)
local function key(k) vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes(k, true, false, true), 'mx', false); vim.wait(200, function() return false end, 20) end
key('j')
local cy_keys = center_and_band()
-- the wheel lands under the pointer: over the pane, with focus on the explorer
--   ⚠️ a mouse event queued by nvim_input_mouse is not read while this probe's
--      lua runs (measured: the pointer moved, the map never fired). so the event
--      only places the pointer, and the wheel KEY is fed through the maps, as a
--      terminal's wheel arrives
vim.api.nvim_set_current_win(ex.winid)
local pos = vim.api.nvim_win_get_position(win)
vim.api.nvim_input_mouse('move', '', '', 0, pos[1] + 3, pos[2] + 3)
vim.wait(100, function() return vim.fn.getmousepos().winid == win end, 10)
key('<ScrollWheelDown>')
local cy_wheel, band1 = center_and_band()
say(('pan cy=%.3f keys=%.3f wheel=%.3f band_before=%s band_after=%s sends=%d'):format(
  cy0 or -1, cy_keys or -1, cy_wheel or -1, tostring(band0), tostring(band1), sends))
say(('pan_keys_move=%s'):format((cy_keys or 0) > (cy0 or 1) and 'hit' or 'miss'))
say(('pan_wheel_moves=%s'):format((cy_wheel or 0) > (cy_keys or 1) and 'hit' or 'miss'))
say(('pan_sends_none=%s'):format(sends == 0 and band0 == band1 and band0 ~= 'none' and 'hit' or 'miss'))

-- the long pan: j down the whole page. kitty holds the whole image, so the page
-- bottom costs no send at all (a send per step per pane is what each j once cost)
local sends_before, steps = sends, 0
local cy_prev = cy_wheel
vim.api.nvim_set_current_win(win)
for _ = 1, 30 do
  key('j'); steps = steps + 1
  local cy = center_and_band()
  if cy == cy_prev then break end
  cy_prev = cy
end
local npanes = #(report() or {})
local recuts = sends - sends_before
say(('pan_long steps=%d cy_end=%.3f sends=%d panes=%d'):format(steps, cy_prev or -1, recuts, npanes))
say(('pan_long_reaches_end=%s'):format(steps > 1 and steps < 30 and 'hit' or 'miss'))
say(('pan_long_few_sends=%s'):format(npanes > 0 and recuts == 0 and 'hit' or 'miss'))

-- the jumps: gg lands at the top, G at the bottom, and k moves at once from there
key('gg')
local cy_top = center_and_band()
key('G')
local cy_bottom = center_and_band()
key('k')
local cy_up = center_and_band()
say(('jump top=%.3f bottom=%.3f k_after_G=%.3f'):format(cy_top or -1, cy_bottom or -1, cy_up or -1))
say(('jump_gg_top=%s'):format((cy_top or 1) < 0.1 and 'hit' or 'miss'))
say(('jump_G_bottom=%s'):format((cy_bottom or 0) > 0.9 and 'hit' or 'miss'))
say(('jump_then_pan=%s'):format((cy_up or 1) < (cy_bottom or 0) and 'hit' or 'miss'))

vim.fn.delete(root, 'rf')
quit()
