# nvim treesitter parser error

## .what

the error `Parser could not be created for buffer X and language "lua"` occurs when neovim's builtin treesitter attempts to create a parser but fails because the parser `.so` file is not in the runtimepath.

## .why it happens

1. **nvim's builtin ftplugin** (`/usr/share/nvim/runtime/ftplugin/lua.lua`) unconditionally calls `vim.treesitter.start()`
2. **no parser available** - the lua parser isn't in nvim's runtime path
3. **load order issue** - nvim-treesitter plugin hasn't loaded yet to add its parser directory to runtimepath

## .key distinction

| feature | neovim builtin | nvim-treesitter plugin |
|---------|---------------|------------------------|
| parse API | yes | uses builtin |
| parser files (.so) | no | yes - manages installation |
| `:TSInstall` | no | yes |

## .root cause with lazy.nvim

with lazy load enabled, nvim-treesitter may not have loaded when:
1. nvim opens a file directly (`nvim file.lua`)
2. `FileType` event triggers `ftplugin/lua.lua`
3. `vim.treesitter.start()` is called
4. nvim-treesitter hasn't yet added its parser directory to runtimepath

## .solutions

### option 1: wrap vim.treesitter.start (recommended)

```lua
-- at top of init.lua, before lazy.nvim
local orig_ts_start = vim.treesitter.start
vim.treesitter.start = function(bufnr, lang)
  pcall(orig_ts_start, bufnr, lang)
end
```

### option 2: don't lazy-load nvim-treesitter

```lua
{
  'nvim-treesitter/nvim-treesitter',
  lazy = false,  -- CRITICAL: must not lazy-load
  priority = 1000,
  build = ':TSUpdate',
}
```

### option 3: stop treesitter on special buffers

```lua
vim.api.nvim_create_autocmd('FileType', {
  pattern = 'lua',
  callback = function(args)
    if vim.bo[args.buf].buftype ~= '' then
      vim.schedule(function()
        pcall(vim.treesitter.stop, args.buf)
      end)
    end
  end,
})
```

## .for virtual buffers (codediff, diffview, etc)

plugins that create virtual buffers should:
1. set `buftype = 'nofile'` before filetype
2. or not set filetype at all
3. or use pcall when they call treesitter functions

## .sources

- [neovim/neovim#31335](https://github.com/neovim/neovim/issues/31335) - disable automatic treesitter activation
- [neovim/neovim#27951](https://github.com/neovim/neovim/issues/27951) - no parser found for lua
- [nvim-treesitter#8149](https://github.com/nvim-treesitter/nvim-treesitter/issues/8149) - parser error with diffview
- [nvim-treesitter wiki](https://github.com/nvim-treesitter/nvim-treesitter/wiki/Installation) - does NOT support lazy load
- [lazyvim treesitter docs](https://www.lazyvim.org/plugins/treesitter)
