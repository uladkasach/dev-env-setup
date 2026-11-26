-- .what = render one photo the way image.nvim would on a hidpi pane, and record what
--         would reach the terminal: the png it transmits, and the placement it asks for
--
-- .the world
--   a 4800x2400 photo-like jpeg (plasma), drawn into a 200x50 cell pane of 20x40 px
--   cells ⇒ image.nvim asks the processor for a 4000x2000 png
--
-- .the arms
--   remote   the play sets SSH_TTY ⇒ init.lua caps the send. owes: the png within the
--            pixel budget, the placement rect scaled to it, and a cell box of 200x50
--   local    no ssh env ⇒ as shipped: a window-sized png, no cell box. this is the
--            defect shape, so the play reads it as the clamp that bites
--
-- ⚠️ headless nvim has no terminal, so the probe fixes the cell size and swaps the
--    terminal write for a recorder. the transform is the REAL imagemagick run
--
-- .rows written: world=…, then key=value rows the play judges

local out = vim.fn.fnamemodify(os.getenv('PROBE_OUT'), ':p')
local arm = os.getenv('PROBE_ARM') or 'remote'
local rows = {}
local function say(s) rows[#rows + 1] = s; vim.fn.writefile(rows, out) end
local function quit() vim.cmd('qa!') end

-- the world: a photo-like jpeg, larger than the pane
local root = vim.fn.tempname()
vim.fn.mkdir(root, 'p')
local magick_bin = vim.fn.executable('magick') == 1 and 'magick' or 'convert'
local src, png = root .. '/photo.jpg', root .. '/sent.png'
vim.fn.system({ magick_bin, '-size', '4800x2400', 'plasma:fractal', '-quality', '85', src })
if vim.fn.filereadable(src) ~= 1 then say('world=absent reason=no_photo_fixture'); return quit() end

-- headless nvim has no tty on fd 1, and the kitty module opens one at load ⇒ a
-- stand-in that swallows writes. every write the probe judges goes to the recorder
local new_tty_shipped = vim.loop.new_tty
vim.loop.new_tty = function(fd, readable)
  local tty = new_tty_shipped(fd, readable)
  if tty then return tty end
  return { write = function() end, close = function() end, is_closing = function() return false end }
end

-- load image.nvim as the shipped config declares it. it may have loaded at startup
-- and failed on the absent tty, so drop what it left and re-run its config
for name in pairs(package.loaded) do
  if name:match('^image') then package.loaded[name] = nil end
end
pcall(function()
  local plugin = require('lazy.core.config').plugins['image.nvim']
  if plugin and plugin._.loaded then require('lazy.core.loader').reload(plugin)
  else require('lazy').load({ plugins = { 'image.nvim' } }) end
end)
local ok_k, kitty = pcall(require, 'image/backends/kitty')
local ok_m, magick = pcall(require, 'image/processors/magick_cli')
local ok_w, wire = pcall(require, 'image/backends/kitty/' .. 'help' .. 'ers')
local ok_t, term = pcall(require, 'image/utils/term')
for name, r in pairs({ kitty = { ok_k, kitty }, magick = { ok_m, magick }, wire = { ok_w, wire }, term = { ok_t, term } }) do
  if not r[1] then
    say(('world=absent reason=image_nvim_not_loaded module=%s err=%s'):format(name, tostring(r[2]):gsub('\n', ' ')))
    return quit()
  end
end
if arm == 'remote' and not kitty.__sends_capped then say('world=absent reason=cap_not_installed'); return quit() end
if arm == 'local' and kitty.__sends_capped then say('world=absent reason=cap_installed_without_ssh'); return quit() end
say('world=present')

-- a fixed hidpi cell, and a recorder in place of the terminal write
term.get_size = function()
  return { cell_width = 20, cell_height = 40, screen_cols = 200, screen_rows = 50, screen_x = 4000, screen_y = 2000 }
end
local calls = {}
local function record(config, data) calls[#calls + 1] = { config = config, data = data } end
-- the transmit goes out through write_graphics, the placement through write_graphics_at;
-- under the cap, the placement is recorded beneath init.lua's wrapper of it
wire.write_graphics = record
if arm == 'remote' then wire.__write_at_shipped = record else wire.write_graphics_at = record end
wire.move_cursor = function() end
wire.restore_cursor = function() end
kitty.state = kitty.state or { options = {}, images = {} }
kitty.state.options = vim.tbl_extend('force', kitty.state.options or {}, { kitty_method = 'normal', kitty_direct_chunk_size = 4096 })
kitty.state.images = kitty.state.images or {}

-- the transform image.nvim would queue for a 200x50 pane
local done
magick.transform(src, { target_width = 4000, target_height = 2000, output_format = 'png', source_format = 'jpeg' }, png,
  function(result) done = result end)
if not vim.wait(60000, function() return done ~= nil end, 20) or not done.ok then
  say('world=absent reason=transform_failed ' .. tostring(done and done.error)); return quit()
end
local dims = vim.fn.system({ 'identify', '-format', '%wx%h', png })
local tw, th = dims:match('(%d+)x(%d+)')
tw, th = tonumber(tw), tonumber(th)
say(('transform_px=%sx%s'):format(tw, th))
say(('sent_bytes=%d'):format(vim.fn.getfsize(png)))

-- the render image.nvim would call
local image = {
  id = 'photo', internal_id = 7, cropped_path = png, resize_hash = 'k',
  bounds = { top = 0, bottom = 49, left = 0, right = 200 },
}
local ok_r, err = pcall(kitty.render, image, 0, 0, 200, 50)
if not ok_r then say('world=absent reason=render_threw ' .. tostring(err)); return quit() end

local place
for _, c in ipairs(calls) do if c.config.action == 'p' then place = c.config end end
if not place then
  local actions = {}
  for _, c in ipairs(calls) do actions[#actions + 1] = tostring(c.config.action) end
  local utils_term = require('image/utils').term
  say(('world=absent reason=no_placement writes=%d actions=%s same_term=%s size=%s'):format(#calls,
    table.concat(actions, ','), tostring(utils_term == term), vim.inspect(utils_term.get_size()):gsub('%s+', ' ')))
  return quit()
end
say(('place w=%s h=%s c=%s r=%s'):format(place.display_width, place.display_height,
  tostring(place.display_columns), tostring(place.display_rows)))

-- the judgements
local cap = kitty.__send_max_pixels or 1000000
say(('capped=%s'):format(tw * th <= cap * 1.01 and 'hit' or 'miss'))
local rect_fits = math.abs(place.display_width - tw) <= 2 and math.abs(place.display_height - th) <= 2
say(('rect_matches_png=%s'):format(rect_fits and 'hit' or 'miss'))
local fills = (place.display_columns == 200 and place.display_rows == 50)
  or (place.display_columns == nil and place.display_width == 4000 and place.display_height == 2000)
say(('fills_pane=%s'):format(fills and 'hit' or 'miss'))
say(('aspect=%s'):format(math.abs(tw / th - 2) < 0.01 and 'hit' or 'miss'))

vim.fn.delete(root, 'rf')
quit()
