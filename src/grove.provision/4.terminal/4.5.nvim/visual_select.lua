-- visual_select.lua — the super+v selector, the same nvim in every holder
--
-- .what = turn an nvim fed a terminal's history on stdin into a line selector:
--         enter toggles a linewise selection, ctrl+c copies and keeps it,
--         ctrl+x / q / escape leave
-- .why  = one view in every terminal, so one gesture. two openers feed it:
--           - kitty, with no tmux: an overlay over kitty's scrollback
--             (4.3.2.emulator/visual_select.py)
--           - tmux: a popup over the pane, fed `capture-pane` (2.8.tmux/tmux.conf)
--
-- every map is BUFFER-local: init.lua binds a global <CR> and visual <C-c>, and
-- a buffer map outranks both here, while every other nvim stays untouched

local buf = vim.api.nvim_get_current_buf()

-- the terminal kitty draws, when tmux opened this view in a popup
--   - 🛑 a tmux popup has no pane, so tmux relays NONE of its escapes to kitty:
--     an OSC 52 copy or a kitty user var written to this nvim's own tty is lost
--   - tmux hands the client's tty instead (2.8.tmux/tmux.conf); a write there
--     reaches kitty directly — over ssh too, as the in_tmux hooks' writes do
--   - absent in kitty's own overlay, where this nvim's tty IS kitty's: there
--     the write goes out on stderr, as nvim's own OSC 52 provider sends it
local client_tty = os.getenv('VISUAL_SELECT_CLIENT_TTY')
local function to_terminal(seq)
  local f = client_tty and io.open(client_tty, 'w')
  if not f then return vim.api.nvim_chan_send(2, seq) end
  f:write(seq)
  f:close()
end

-- a copy must reach the desktop clipboard from EVERY box
--   - on the laptop nvim has a SYSTEM provider (wl-copy), and it stays in charge
--   - on a grove it has none; there the copy goes to kitty as OSC 52, which
--     kitty accepts (`clipboard_control` holds write-clipboard)
--   - 🛑 `has('clipboard')` cannot tell those apart: nvim falls back to its own
--     OSC 52 and answers 1 — but inside a tmux popup that OSC 52 goes to the
--     popup's tty, and tmux drops it. so ask WHICH provider nvim picked
--   - only "+" is routed: an OSC 52 paste would wait on a terminal reply
local ok, provider = pcall(vim.fn['provider#clipboard#Executable'])
local system_provider = ok and provider ~= '' and provider ~= 'osc52' and provider ~= 'tmux'
if not system_provider and (client_tty or vim.fn.has('clipboard') == 0) then
  local function copy(lines)
    to_terminal('\027]52;c;' .. vim.base64.encode(table.concat(lines, '\n')) .. '\007')
  end
  vim.g.clipboard = {
    name = 'visual-select-osc52',
    copy = { ['+'] = copy, ['*'] = copy },
    paste = { ['+'] = function() return {} end, ['*'] = function() return {} end },
  }
  -- 🛑 the provider question above LOADED nvim's clipboard provider, and a
  --    loaded provider ignores a later g:clipboard; reload it, as `:h
  --    g:clipboard` directs, so the copy above is the one nvim calls
  vim.g.loaded_clipboard_provider = nil
  vim.cmd('runtime autoload/provider/clipboard.vim')
end

-- while open in a tmux popup, mark kitty's window so super+v closes the view
--   - tmux runs no key bind while a popup is open, so super+v cannot reach
--     tmux's bind; kitty's kitten reads this mark and sends escape instead
--     (4.3.2.emulator/visual_select.py), and escape leaves (below)
--   - set on open, cleared on leave — the same user var write the in_tmux
--     hooks use (OSC 1337 SetUserVar, value base64 "1")
if client_tty then
  to_terminal('\027]1337;SetUserVar=visual_select_tmux=MQ==\007')
  vim.api.nvim_create_autocmd('VimLeavePre', {
    callback = function() to_terminal('\027]1337;SetUserVar=visual_select_tmux=\007') end,
  })
end

-- tmux's `capture-pane -J` keeps the blanks at the end of each row; strip them,
-- so a copy holds the text and never a run of spaces the eye did not see
vim.cmd([[silent! keeppatterns %s/\s\+$//e]])

-- a view, never a file: no save prompt on exit, no edit by accident
vim.bo[buf].buftype = 'nofile'
vim.bo[buf].modified = false
vim.bo[buf].modifiable = false

-- the view keeps the terminal's own width, so its lines wrap where the terminal
-- wrapped them and nowhere else
--   - the minimap is a 13-column split, and the number / sign / fold columns
--     each eat width too; every column they take shifts a wrap the human never saw
--   - this nvim is the overlay's OWN process, so a global `Neominimap Disable`
--     reaches this view alone; every other nvim keeps its minimap
--   - the disable runs now and again on VimEnter: auto_enable may open the
--     minimap after this file is sourced
local function bare_view()
  pcall(vim.cmd, 'silent! Neominimap Disable')
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local wbuf = vim.api.nvim_win_get_buf(win)
    if vim.bo[wbuf].filetype == 'neominimap' then pcall(vim.api.nvim_win_close, win, true) end
  end
  local win = vim.fn.bufwinid(buf)
  if win == -1 then return end
  vim.wo[win].number = false
  vim.wo[win].relativenumber = false
  vim.wo[win].signcolumn = 'no'
  vim.wo[win].foldcolumn = '0'
  -- wrap stays ON: a soft-wrapped terminal line arrives as one long line, and at
  -- full width nvim breaks it at the very column the terminal did
  vim.wo[win].wrap = true
  vim.wo[win].linebreak = false
end
bare_view()
vim.api.nvim_create_autocmd('VimEnter', { once = true, callback = function() vim.schedule(bare_view) end })

-- a view with less history than the human expects says WHY, out loud
--   - kitty sets this when the window's app holds the alternate screen, where
--     kitty keeps no scrollback (4.3.2.emulator/visual_select.py)
local notice = os.getenv('VISUAL_SELECT_NOTICE')
if notice and notice ~= '' then
  vim.api.nvim_create_autocmd('VimEnter', {
    once = true,
    callback = function() vim.schedule(function() vim.notify('super+v: ' .. notice, vim.log.levels.WARN) end) end,
  })
end

-- land on the last line of text, at the bottom of the window — the line the
-- terminal last showed, so the view opens where the eye already was
vim.cmd('normal! G')
vim.fn.search('\\S', 'bcW')
vim.cmd('normal! zb')

local function map(modes, lhs, rhs, desc)
  vim.keymap.set(modes, lhs, rhs, { buffer = buf, nowait = true, desc = desc })
end

-- enter: begin a linewise selection; enter again ends it
map('n', '<CR>', 'V', 'visual select: begin')
map('x', '<CR>', '<Esc>', 'visual select: end')

-- ctrl+c: kitty forwards it as <C-S-c> (copy_notify.py); copy, keep the selection
map('x', '<C-S-c>', '"+ygv', 'visual select: copy')
-- with no selection there is naught to copy, so it leaves — as tmux copy-mode does
map('n', '<C-S-c>', '<Cmd>qa!<CR>', 'visual select: leave')

-- ctrl+x: kitty sends the bare ^C byte (kitty.conf), so it lands as <C-c>
--   - 🛑 the global visual <C-c> is a COPY (the non-kitty fallback in init.lua);
--     here it must leave, or ctrl+x would copy instead of exit
map({ 'n', 'x' }, '<C-c>', '<Cmd>qa!<CR>', 'visual select: leave')
-- q leaves from a selection too, as tmux copy-mode's stock q does
map({ 'n', 'x' }, 'q', '<Cmd>qa!<CR>', 'visual select: leave')
-- escape leaves too, from a selection or not — tmux copy-mode binds it the same
map({ 'n', 'x' }, '<Esc>', '<Cmd>qa!<CR>', 'visual select: leave')
