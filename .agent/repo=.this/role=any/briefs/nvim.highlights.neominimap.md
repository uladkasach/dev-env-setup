# neominimap highlights

ref: [neominimap.nvim](https://github.com/Isrothy/neominimap.nvim) | [git.lua](https://github.com/Isrothy/neominimap.nvim/blob/main/lua/neominimap/map/handlers/builtins/git.lua)

## .git highlight groups

neominimap defines 9 git-related highlight groups:

| group | mode | source |
|-------|------|--------|
| NeominimapGitAddSign | sign | fg from GitSignsAdd |
| NeominimapGitChangeSign | sign | fg from GitSignsChange |
| NeominimapGitDeleteSign | sign | fg from GitSignsDelete |
| NeominimapGitAddIcon | icon | fg from GitSignsAdd |
| NeominimapGitChangeIcon | icon | fg from GitSignsChange |
| NeominimapGitDeleteIcon | icon | fg from GitSignsDelete |
| NeominimapGitAddLine | line | bg from GitSignsAdd |
| NeominimapGitChangeLine | line | bg from GitSignsChange |
| NeominimapGitDeleteLine | line | bg from GitSignsDelete |

## .modes

| mode | display | highlight used |
|------|---------|----------------|
| line | background color regions | `*Line` groups |
| sign | braille characters | `*Sign` groups |
| icon | custom text icons | `*Icon` groups |

## .default behavior

all groups set with `default = true` - they derive colors from gitsigns but can be overridden.

- `*Sign` and `*Icon` groups use **foreground** color from gitsigns
- `*Line` groups use **background** color from gitsigns

## .configuration

```lua
vim.g.neominimap = {
  git = {
    enabled = true,
    mode = 'line',  -- 'line', 'sign', or 'icon'
    priority = 6,
    icon = {
      add = '+ ',
      change = '~ ',
      delete = '- ',
    },
  },
}
```

## .custom colors

to override neominimap git colors independently from gitsigns:

```lua
-- line mode (background colors)
vim.api.nvim_set_hl(0, 'NeominimapGitAddLine', { bg = '#5a7a5a' })
vim.api.nvim_set_hl(0, 'NeominimapGitChangeLine', { bg = '#7a7a5a' })
vim.api.nvim_set_hl(0, 'NeominimapGitDeleteLine', { bg = '#7a5a5a' })

-- sign mode (foreground colors)
vim.api.nvim_set_hl(0, 'NeominimapGitAddSign', { fg = '#98FB98' })
vim.api.nvim_set_hl(0, 'NeominimapGitChangeSign', { fg = '#F0E68C' })
vim.api.nvim_set_hl(0, 'NeominimapGitDeleteSign', { fg = '#FF8080' })
```

## .dependency

requires [gitsigns.nvim](https://github.com/lewis6991/gitsigns.nvim) for git data.

neominimap reads hunk data from gitsigns but renders with its own highlight groups, so gutter and minimap colors can differ.

## .other highlight groups

neominimap also has groups for:
- diagnostics: `NeominimapDiagnostic{Error,Warn,Info,Hint}{Line,Sign,Icon}`
- search: `NeominimapSearch{Line,Sign,Icon}`
- marks: `NeominimapMark{Line,Sign,Icon}`
