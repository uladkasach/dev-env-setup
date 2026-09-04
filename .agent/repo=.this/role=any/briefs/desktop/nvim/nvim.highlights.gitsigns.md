# gitsigns highlights

ref: [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) | [highlight.lua](https://github.com/lewis6991/gitsigns.nvim/blob/main/lua/gitsigns/highlight.lua)

## .pattern

`GitSigns[Staged]{Type}{Variant}`

## .types

| type | purpose | default text |
|------|---------|--------------|
| Add | added lines | `┃` |
| Change | modified lines | `┃` |
| Delete | deleted lines | `▁` |
| Topdelete | delete at hunk top | `▔` |
| Changedelete | change + delete | `~` |
| Untracked | untracked files | `┆` |

## .variants

| suffix | purpose | enable via |
|--------|---------|------------|
| (none) | sign column text | always |
| Nr | line number color | `numhl = true` |
| Ln | line background | `linehl = true` |
| Cul | cursor line bg | `culhl = true` |

## .all groups

### unstaged (24 groups)

```
GitSignsAdd          GitSignsAddNr          GitSignsAddLn          GitSignsAddCul
GitSignsChange       GitSignsChangeNr       GitSignsChangeLn       GitSignsChangeCul
GitSignsDelete       GitSignsDeleteNr       GitSignsDeleteLn       GitSignsDeleteCul
GitSignsTopdelete    GitSignsTopdeleteNr    GitSignsTopdeleteLn    GitSignsTopdeleteCul
GitSignsChangedelete GitSignsChangedeleteNr GitSignsChangedeleteLn GitSignsChangedeleteCul
GitSignsUntracked    GitSignsUntrackedNr    GitSignsUntrackedLn    GitSignsUntrackedCul
```

### staged (24 groups)

same pattern with `Staged` prefix:
```
GitSignsStagedAdd       GitSignsStagedAddNr       GitSignsStagedAddLn       ...
GitSignsStagedChange    GitSignsStagedChangeNr    GitSignsStagedChangeLn    ...
GitSignsStagedDelete    GitSignsStagedDeleteNr    GitSignsStagedDeleteLn    ...
```

enable via `signs_staged_enable = true`

### special groups

| group | purpose |
|-------|---------|
| GitSignsAddInline | word diff add (preview) |
| GitSignsChangeInline | word diff change (preview) |
| GitSignsDeleteInline | word diff delete (preview) |
| GitSignsAddLnInline | word diff add (buffer) |
| GitSignsChangeLnInline | word diff change (buffer) |
| GitSignsDeleteLnInline | word diff delete (buffer) |
| GitSignsDeleteVirtLn | virtual line for deletes |
| GitSignsCurrentLineBlame | inline blame text |
| GitSignsAddPreview | preview window add |
| GitSignsDeletePreview | preview window delete |

## .fallback chain

undefined groups fall back through:
`GitSignsAdd` → `GitGutterAdd` → `SignifySignAdd` → `DiffAddedGutter` → `Added` → `DiffAdd`

## .configuration

```lua
require('gitsigns').setup({
  signs_staged_enable = true,  -- show staged changes
  numhl = false,               -- highlight line numbers
  linehl = false,              -- highlight entire line
  culhl = false,               -- highlight cursor line
  word_diff = false,           -- show word diffs
  signs = {
    add = { text = '┃' },
    change = { text = '┃' },
    delete = { text = '▁' },
    topdelete = { text = '▔' },
    changedelete = { text = '~' },
    untracked = { text = '┆' },
  },
})
```

## .highlight definition

to set gutter sign color only (no line bg):
```lua
vim.api.nvim_set_hl(0, 'GitSignsAdd', { fg = '#98FB98' })
```

to set line background:
```lua
vim.api.nvim_set_hl(0, 'GitSignsAddLn', { bg = '#3a4a3a' })
```
