-- bootstrap lazy.nvim plugin manager
local lazypath = vim.fn.stdpath('data') .. '/lazy/lazy.nvim'
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    'git', 'clone', '--filter=blob:none',
    'https://github.com/folke/lazy.nvim.git',
    '--branch=stable', lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- shared diff boundary navigation
local function navigate_diff_boundary(direction, get_chunks, fallback)
  local chunks = get_chunks()
  if not chunks or #chunks == 0 then return end
  local cursor = vim.api.nvim_win_get_cursor(0)[1]
  if direction == 'down' then
    for i, c in ipairs(chunks) do
      if cursor >= c.start and cursor < c.fin then
        vim.api.nvim_win_set_cursor(0, { c.fin, 0 })
        print('chunk ' .. i .. ' bot')
        return
      elseif cursor == c.fin then
        local next_idx = chunks[i + 1] and (i + 1) or 1
        vim.api.nvim_win_set_cursor(0, { chunks[next_idx].start, 0 })
        print('chunk ' .. next_idx .. ' top')
        return
      end
    end
  else -- up
    for i, c in ipairs(chunks) do
      if cursor > c.start and cursor <= c.fin then
        vim.api.nvim_win_set_cursor(0, { c.start, 0 })
        print('chunk ' .. i .. ' top')
        return
      elseif cursor == c.start then
        local prev_idx = chunks[i - 1] and (i - 1) or #chunks
        vim.api.nvim_win_set_cursor(0, { chunks[prev_idx].fin, 0 })
        print('chunk ' .. prev_idx .. ' bot')
        return
      end
    end
  end
  -- not in a chunk, use fallback
  if fallback then fallback() end
end

-- get chunks from vim diff highlights
local function get_diff_hl_chunks()
  local chunks = {}
  local lines = vim.api.nvim_buf_line_count(0)
  local in_chunk = false
  local chunk_start = nil
  for lnum = 1, lines do
    local hl = vim.fn.diff_hlID(lnum, 1)
    local is_diff = hl > 0
    if is_diff and not in_chunk then
      in_chunk = true
      chunk_start = lnum
    elseif not is_diff and in_chunk then
      table.insert(chunks, { start = chunk_start, fin = lnum - 1 })
      in_chunk = false
    end
  end
  if in_chunk then
    table.insert(chunks, { start = chunk_start, fin = lines })
  end
  return chunks
end

-- plugins
require('lazy').setup({
  {
    'lewis6991/gitsigns.nvim',
    config = function()
      local gs = require('gitsigns')
      gs.setup({})
      -- get chunks from gitsigns hunks
      local function get_gitsigns_chunks()
        local hunks = gs.get_hunks()
        if not hunks then return {} end
        local chunks = {}
        for _, h in ipairs(hunks) do
          table.insert(chunks, {
            start = h.added.start,
            fin = h.added.start + math.max(h.added.count - 1, 0),
          })
        end
        return chunks
      end
      -- ctrl+d alone shows hint
      vim.keymap.set('n', '<C-d>', function()
        print('diff: j=down k=up')
      end, { desc = 'Diff navigation hint' })
      -- ctrl+d j/k to navigate diff boundaries
      local function boundary_down()
        navigate_diff_boundary('down', get_gitsigns_chunks, function()
          gs.next_hunk({ navigation_message = false })
        end)
      end
      local function boundary_up()
        navigate_diff_boundary('up', get_gitsigns_chunks, function()
          gs.prev_hunk({ navigation_message = false })
        end)
      end
      vim.keymap.set('n', '<C-d>j', boundary_down, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d>k', boundary_up, { desc = 'Prev diff boundary' })
      vim.keymap.set('n', '<C-d><C-j>', boundary_down, { desc = 'Next diff boundary' })
      vim.keymap.set('n', '<C-d><C-k>', boundary_up, { desc = 'Prev diff boundary' })
    end,
  },
  {
    'sindrets/diffview.nvim',
    dependencies = { 'nvim-lua/plenary.nvim', 'mrjones2014/smart-splits.nvim' },
    config = function()
      local ss = require('smart-splits')
      local actions = require('diffview.actions')
      require('diffview').setup({
        view = {
          default = { layout = 'diff2_vertical' },
          merge_tool = { layout = 'diff3_mixed' },
        },
        keymaps = {
          disable_defaults = false,
          view = {
            ['<C-h>'] = ss.move_cursor_left,
            ['<C-j>'] = ss.move_cursor_down,
            ['<C-k>'] = ss.move_cursor_up,
            ['<C-l>'] = ss.move_cursor_right,
            ['o'] = function()
              local lib = require('diffview.lib')
              local view = lib.get_current_view()
              local path = nil
              -- try to get path from layout
              if view and view.cur_layout and view.cur_layout.b then
                local file = view.cur_layout.b.file
                if file then path = file.path end
              end
              -- fallback: parse from buffer name
              if not path then
                local bufname = vim.api.nvim_buf_get_name(0)
                path = bufname:match('diffview://.-/(.+)')
              end
              if path and path ~= '' then
                -- open in new tab, keep diffview open
                vim.cmd('tabnew ' .. vim.fn.fnameescape(path))
              end
            end,
            ['<C-d>j'] = function()
              navigate_diff_boundary('down', get_diff_hl_chunks, function()
                vim.cmd('normal! ]c')
              end)
            end,
            ['<C-d>k'] = function()
              navigate_diff_boundary('up', get_diff_hl_chunks, function()
                vim.cmd('normal! [c')
              end)
            end,
            ['<C-d><C-j>'] = function()
              navigate_diff_boundary('down', get_diff_hl_chunks, function()
                vim.cmd('normal! ]c')
              end)
            end,
            ['<C-d><C-k>'] = function()
              navigate_diff_boundary('up', get_diff_hl_chunks, function()
                vim.cmd('normal! [c')
              end)
            end,
          },
          file_panel = {
            ['<C-h>'] = ss.move_cursor_left,
            ['<C-j>'] = ss.move_cursor_down,
            ['<C-k>'] = ss.move_cursor_up,
            ['<C-l>'] = ss.move_cursor_right,
            ['o'] = function()
              local lib = require('diffview.lib')
              local view = lib.get_current_view()
              if view then
                local file = view.panel:get_item_at_cursor()
                if file and file.path then
                  vim.cmd('DiffviewClose')
                  vim.cmd('edit ' .. vim.fn.fnameescape(file.path))
                end
              end
            end,
          },
          file_history_panel = {
            ['<C-h>'] = ss.move_cursor_left,
            ['<C-j>'] = ss.move_cursor_down,
            ['<C-k>'] = ss.move_cursor_up,
            ['<C-l>'] = ss.move_cursor_right,
            ['o'] = function()
              local lib = require('diffview.lib')
              local view = lib.get_current_view()
              if view then
                local file = view.panel:get_item_at_cursor()
                if file and file.path then
                  vim.cmd('DiffviewClose')
                  vim.cmd('edit ' .. vim.fn.fnameescape(file.path))
                end
              end
            end,
          },
        },
      })
      -- ctrl+g = toggle between diff view and file tabs
      local last_file_tab = nil
      vim.keymap.set('n', '<C-g>', function()
        local lib = require('diffview.lib')
        local view = lib.get_current_view()
        if view then
          -- in diffview: go to last file tab or previous tab
          if last_file_tab and vim.api.nvim_tabpage_is_valid(last_file_tab) then
            vim.api.nvim_set_current_tabpage(last_file_tab)
          else
            vim.cmd('tabprevious')
          end
        else
          -- not in diffview: save current tab, find or open diffview
          last_file_tab = vim.api.nvim_get_current_tabpage()
          -- find diffview tab
          for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
            local wins = vim.api.nvim_tabpage_list_wins(tab)
            for _, win in ipairs(wins) do
              local buf = vim.api.nvim_win_get_buf(win)
              local name = vim.api.nvim_buf_get_name(buf)
              if name:match('^diffview://') then
                vim.api.nvim_set_current_tabpage(tab)
                return
              end
            end
          end
          -- no diffview tab, open new one
          vim.cmd('DiffviewOpen')
        end
      end, { desc = 'Toggle diff view' })
    end,
  },
  {
    'nvim-lualine/lualine.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    opts = {
      options = {
        theme = {
          normal = {
            a = { fg = '#333333', bg = '#F5DEB3', gui = 'bold' },
            b = { fg = '#FFFFFF', bg = '#555555' },
            c = { fg = '#F5DEB3', bg = '#333333' },
          },
          insert = { a = { fg = '#333333', bg = '#98FB98', gui = 'bold' } },
          visual = { a = { fg = '#333333', bg = '#F0E68C', gui = 'bold' } },
          replace = { a = { fg = '#333333', bg = '#FF2B2B', gui = 'bold' } },
          inactive = {
            a = { fg = '#777777', bg = '#333333' },
            b = { fg = '#777777', bg = '#333333' },
            c = { fg = '#777777', bg = '#333333' },
          },
        },
        component_separators = { left = '│', right = '│' },
        section_separators = { left = '', right = '' },
        globalstatus = true,
      },
      sections = {
        lualine_a = { { 'mode', fmt = string.lower } },
        lualine_b = { 'branch', 'diff' },
        lualine_c = { {
          'filename',
          fmt = function(name)
            local ft = vim.bo.filetype
            if ft == 'DiffviewFiles' then return 'diff tree' end
            if ft == 'DiffviewFileHistory' then return 'diff history' end
            if ft == 'neo-tree' then return 'files' end
            if ft == 'oil' then return 'oil' end
            return name
          end,
        } },
        lualine_x = { {
          'filetype',
          fmt = function(ft)
            if ft == 'DiffviewFiles' then return 'diff' end
            if ft == 'DiffviewFileHistory' then return 'history' end
            if ft == 'neo-tree' then return 'tree' end
            if ft == 'oil' then return 'oil' end
            return ft
          end,
        } },
        lualine_y = { 'location' },
        lualine_z = { { 'progress', fmt = string.lower } },
      },
    },
  },
  {
    'mrjones2014/smart-splits.nvim',
    version = '>=1.0.0',
    config = function()
      local ss = require('smart-splits')
      ss.setup({})
      -- navigate between windows
      vim.keymap.set('n', '<C-h>', ss.move_cursor_left)
      vim.keymap.set('n', '<C-j>', ss.move_cursor_down)
      vim.keymap.set('n', '<C-k>', ss.move_cursor_up)
      vim.keymap.set('n', '<C-l>', ss.move_cursor_right)
      -- resize windows with alt+hjkl
      vim.keymap.set('n', '<A-h>', ss.resize_left)
      vim.keymap.set('n', '<A-j>', ss.resize_down)
      vim.keymap.set('n', '<A-k>', ss.resize_up)
      vim.keymap.set('n', '<A-l>', ss.resize_right)
    end,
  },
  {
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    opts = {
      window = {
        position = 'left',
        width = 30,
        mappings = {
          ['o'] = function(state)
            local node = state.tree:get_node()
            local path = node.type == 'directory' and node.path or vim.fn.fnamemodify(node.path, ':h')
            require('oil').open(path)
          end,
        },
      },
      filesystem = {
        filtered_items = {
          visible = true,
          hide_dotfiles = false,
          hide_gitignored = false,
        },
      },
    },
  },
  {
    'stevearc/oil.nvim',
    dependencies = { 'nvim-tree/nvim-web-devicons' },
    config = function()
      require('oil').setup({
        columns = { 'icon' },
        view_options = {
          show_hidden = true,
        },
        keymaps = {
          ['<C-h>'] = false,  -- don't override window nav
          ['<C-l>'] = false,
        },
      })
      -- `-` opens parent directory
      vim.keymap.set('n', '-', '<CMD>Oil<CR>', { desc = 'Open parent directory' })
    end,
  },
})

-- disable tabline
vim.opt.showtabline = 0

-- colorscheme: ptyxis Desert palette
-- ref: https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml
vim.cmd('highlight clear')
local hi = function(group, opts) vim.api.nvim_set_hl(0, group, opts) end

-- ui
hi('Normal',       { fg = '#FFFFFF', bg = '#333333' })
hi('CursorLine',   { bg = '#4D4D4D' })
hi('CursorLineNr', { fg = '#F0E68C', bold = true })
hi('LineNr',       { fg = '#555555' })
hi('Visual',       { bg = '#555555' })
hi('Pmenu',        { fg = '#FFFFFF', bg = '#4D4D4D' })
hi('PmenuSel',     { fg = '#333333', bg = '#F0E68C' })
hi('StatusLine',   { fg = '#333333', bg = '#F5DEB3' })
hi('StatusLineNC', { fg = '#333333', bg = '#4D4D4D' })
hi('Search',       { fg = '#333333', bg = '#F0E68C' })
hi('MatchParen',   { fg = '#FFFFFF', bg = '#555555', bold = true })

-- syntax
hi('Comment',      { fg = '#777777', italic = true })
hi('String',       { fg = '#98FB98' })
hi('Number',       { fg = '#FFDEAD' })
hi('Boolean',      { fg = '#FFDEAD' })
hi('Float',        { fg = '#FFDEAD' })
hi('Keyword',      { fg = '#F0E68C' })
hi('Statement',    { fg = '#F0E68C' })
hi('Conditional',  { fg = '#F0E68C' })
hi('Repeat',       { fg = '#F0E68C' })
hi('Function',     { fg = '#C4A882' })
hi('Identifier',   { fg = '#FFA0A0' })
hi('Type',         { fg = '#FFD700' })
hi('Constant',     { fg = '#FFDEAD' })
hi('PreProc',      { fg = '#CD853F' })
hi('Include',      { fg = '#CD853F' })
hi('Operator',     { fg = '#F5DEB3' })
hi('Delimiter',    { fg = '#F5DEB3' })
hi('Special',      { fg = '#FFA0A0' })
hi('Error',        { fg = '#FF2B2B', bold = true })
hi('WarnMsg',      { fg = '#FF5555' })
hi('Todo',         { fg = '#333333', bg = '#F0E68C', bold = true })
hi('Title',        { fg = '#C4A882', bold = true })
hi('Directory',    { fg = '#C4A882' })

-- neo-tree
hi('NeoTreeDirectoryName',  { fg = '#F5DEB3' })
hi('NeoTreeDirectoryIcon',  { fg = '#C4A882' })
hi('NeoTreeFileName',       { fg = '#FFFFFF' })
hi('NeoTreeGitAdded',       { fg = '#98FB98' })
hi('NeoTreeGitDeleted',     { fg = '#FF2B2B' })
hi('NeoTreeGitModified',    { fg = '#F0E68C' })
hi('NeoTreeGitUntracked',   { fg = '#555555' })
hi('NeoTreeIndentMarker',   { fg = '#555555' })
hi('NeoTreeRootName',       { fg = '#F0E68C', bold = true })
hi('NeoTreeTitleBar',       { fg = '#333333', bg = '#F5DEB3' })
hi('NeoTreeFloatBorder',    { fg = '#555555' })
hi('NeoTreeCursorLine',     { bg = '#4D4D4D' })

-- oil
hi('OilDir',               { fg = '#C4A882' })
hi('OilDirIcon',           { fg = '#C4A882' })
hi('OilFile',              { fg = '#FFFFFF' })
hi('OilCreate',            { fg = '#98FB98' })
hi('OilDelete',            { fg = '#FF2B2B' })
hi('OilMove',              { fg = '#F0E68C' })
hi('OilCopy',              { fg = '#87CEFF' })
hi('OilChange',            { fg = '#F0E68C' })

-- diff
hi('DiffAdd',      { fg = '#98FB98', bg = '#333333' })
hi('DiffDelete',   { fg = '#FF2B2B', bg = '#333333' })
hi('DiffChange',   { fg = '#F0E68C', bg = '#333333' })
hi('DiffText',     { fg = '#333333', bg = '#F0E68C' })

-- diffview
hi('DiffviewFilePanelTitle',      { fg = '#F0E68C', bold = true })
hi('DiffviewFilePanelCounter',    { fg = '#F5DEB3' })
hi('DiffviewFilePanelFileName',   { fg = '#FFFFFF' })
hi('DiffviewFilePanelPath',       { fg = '#777777' })
hi('DiffviewDim1',                { fg = '#555555' })

-- ctrl+c = copy (visual mode)
vim.keymap.set('v', '<C-c>', '"+y')

-- ctrl+v = paste (insert + normal mode)
vim.keymap.set('i', '<C-v>', '<C-r>+')
vim.keymap.set('n', '<C-v>', '"+p')

-- ctrl+s = save and exit to normal mode
vim.keymap.set('n', '<C-s>', ':w<CR>')
vim.keymap.set('i', '<C-s>', '<Esc>:w<CR>')

-- ctrl+e = smart file tree toggle
-- if neo-tree not open: open and focus it
-- if neo-tree open but not focused: focus it
-- if neo-tree open and focused: close it
vim.keymap.set('n', '<C-e>', function()
  local bufname = vim.api.nvim_buf_get_name(0)
  local filetype = vim.bo.filetype
  if filetype == 'neo-tree' then
    vim.cmd('Neotree close')
  else
    vim.cmd('Neotree focus')
  end
end, { noremap = true, silent = true })

-- ctrl+h/j/k/l = navigate between windows (configured in smart-splits plugin above)

-- ctrl+z = undo, ctrl+shift+z = redo (standard keybinds)
vim.keymap.set('n', '<C-z>', 'u', { noremap = true })
vim.keymap.set('i', '<C-z>', '<Esc>ui', { noremap = true })
vim.keymap.set('n', '<C-S-z>', '<C-r>', { noremap = true })
vim.keymap.set('i', '<C-S-z>', '<Esc><C-r>i', { noremap = true })

-- ctrl+r = copy relative path of current file to clipboard (relative to cwd)
vim.keymap.set('n', '<C-r>', function()
  local path = vim.fn.expand('%:.')
  vim.fn.setreg('+', path)
  print('copied: ' .. path)
end, { noremap = true, silent = false })
