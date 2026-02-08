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
    'nvim-neo-tree/neo-tree.nvim',
    branch = 'v3.x',
    dependencies = {
      'nvim-lua/plenary.nvim',
      'nvim-tree/nvim-web-devicons',
      'MunifTanjim/nui.nvim',
    },
    opts = {
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

-- ctrl+e = toggle file tree
vim.keymap.set('n', '<C-e>', ':Neotree toggle<CR>')
