# neominimap custom handler for codediff

## .what

neominimap's built-in git handler reads from gitsigns, which tracks work tree changes. it doesn't show diff regions in codediff panes because codediff uses extmarks, not vim's native diff mode.

## .problem

| context | how highlights work | neominimap support |
|---------|--------------------|--------------------|
| normal buffer | gitsigns hunks | built-in git handler |
| vimdiff | `vim.wo[win].diff` + `diff_hlID()` | none by default |
| codediff panes | extmarks with `CodeDiffLineInsert`/`CodeDiffLineDelete` | none by default |

## .solution

register a custom handler at runtime that reads both:
1. vim's native `diff_hlID()` for vimdiff
2. extmarks for codediff buffers

## .handler registration

neominimap's `handlers` config in `vim.g.neominimap` expects module paths, not inline definitions. inline definitions cause "loop or previous error" on module load.

instead, register handlers at runtime after the plugin loads:

```lua
config = function()
  vim.defer_fn(function()
    local ok, handlers = pcall(require, 'neominimap.map.handlers')
    if not ok then return end

    handlers.register({
      name = 'vdiff',
      mode = 'line',
      namespace = vim.api.nvim_create_namespace('neominimap_vdiff'),
      init = function() end,
      autocmds = { ... },
      get_annotations = function(bufnr) ... end,
    })
  end, 100)
end,
```

## .handler structure

| field | type | purpose |
|-------|------|---------|
| name | string | unique identifier |
| mode | `'line'` \| `'sign'` \| `'icon'` | display method |
| namespace | integer | nvim namespace from `nvim_create_namespace` |
| init | function | called once on registration (can be empty) |
| autocmds | table | events that trigger updates |
| get_annotations | function(bufnr) | returns annotation objects |

## .annotation structure

```lua
{
  lnum = integer,      -- start line (1-indexed)
  end_lnum = integer,  -- end line
  id = integer,        -- group id (to combine annotations)
  priority = integer,  -- display priority
  highlight = string,  -- highlight group name
}
```

## .detect codediff buffers

codediff buffer names match pattern `codediff:N/path`:

```lua
local bufname = vim.api.nvim_buf_get_name(bufnr)
local is_codediff = bufname:match('codediff:')
```

## .read codediff extmarks

codediff uses these highlight groups:
- `CodeDiffLineInsert` (links to DiffAdd) for additions
- `CodeDiffLineDelete` (links to DiffDelete) for deletions

read extmarks per line:

```lua
local lnum0 = lnum - 1  -- 0-indexed
for _, ns_id in pairs(vim.api.nvim_get_namespaces()) do
  local marks = vim.api.nvim_buf_get_extmarks(bufnr, ns_id, { lnum0, 0 }, { lnum0, -1 }, { details = true })
  for _, mark in ipairs(marks) do
    local details = mark[4]
    if details and details.hl_group then
      local hl = details.hl_group
      if hl == 'CodeDiffLineInsert' then ... end
      if hl == 'CodeDiffLineDelete' then ... end
    end
  end
end
```

## .read vim diff highlights

for native vimdiff, check window diff mode and use `diff_hlID`:

```lua
local win = vim.fn.bufwinid(bufnr)
local is_vimdiff = win ~= -1 and vim.wo[win].diff

local hl_id = vim.fn.diff_hlID(lnum, 1)
if hl_id > 0 then
  local hl_name = vim.fn.synIDattr(hl_id, 'name')
  -- hl_name is 'DiffAdd', 'DiffChange', 'DiffDelete', or 'DiffText'
end
```

## .highlight groups

define custom highlight groups for the handler:

```lua
hi('NeominimapDiffAddLine',    { bg = '#5a7a5a' })
hi('NeominimapDiffChangeLine', { bg = '#7a7a5a' })
hi('NeominimapDiffDeleteLine', { bg = '#7a5a5a' })
```

## .autocmd events

trigger handler updates on:
- `BufEnter` - on buffer enter
- `DiffUpdated` - on diff change (vimdiff)
- `TextChanged` - on buffer text change (codediff)

## .references

- [neominimap.nvim](https://github.com/Isrothy/neominimap.nvim)
- [codediff.nvim](https://github.com/esmuellert/codediff.nvim)
- neominimap handler source: `lua/neominimap/map/handlers/init.lua`
