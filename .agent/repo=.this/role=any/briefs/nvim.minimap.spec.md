# minimap.spec

## .what

birdseye scrollbar view — shows file position and git changes.

## .requirements

| req | description |
|-----|-------------|
| split pane | real window split, not float — text wraps at boundary, doesn't go under |
| width = 12.9 | matches the `line:col \| %` box in lualine |
| gitsigns integration | displays add/delete/change hunks in the scrollbar |
| gitdiff support | visible in gitdiff.pane.tree and gitdiff.pane.file |

## .keybinds

| key | action |
|-----|--------|
| `Ctrl+m` | toggle minimap on/off |

## .behavior

- enabled by default
- excluded from: neo-tree, oil, help, lazy
- in gitdiff.pane.tree: displays minimap for the "after" file pane
- updates on scroll to track cursor position

## .implementation

neominimap.nvim with `layout = 'split'`.
