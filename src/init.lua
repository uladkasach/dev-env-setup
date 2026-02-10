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

-- plugins
require('lazy').setup({
  { 'lewis6991/gitsigns.nvim', config = true },
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
        lualine_c = { 'filename' },
        lualine_x = { 'filetype' },
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
      vim.keymap.set('n', '<C-h>', ss.move_cursor_left)
      vim.keymap.set('n', '<C-j>', ss.move_cursor_down)
      vim.keymap.set('n', '<C-k>', ss.move_cursor_up)
      vim.keymap.set('n', '<C-l>', ss.move_cursor_right)
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
})

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

-- diff
hi('DiffAdd',      { fg = '#98FB98', bg = '#333333' })
hi('DiffDelete',   { fg = '#FF2B2B', bg = '#333333' })
hi('DiffChange',   { fg = '#F0E68C', bg = '#333333' })
hi('DiffText',     { fg = '#333333', bg = '#F0E68C' })

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
