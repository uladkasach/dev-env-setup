# gitsigns + minimap color spec

## .what

gitsigns and neominimap display git changes with distinct visual treatment per context.

## .gutter (gitsigns)

sign column shows `┃` character with foreground color only.

| state | add | change | delete |
|-------|-----|--------|--------|
| unstaged | bright green fg | bright yellow fg | bright red fg |
| staged | muted green fg | muted yellow fg | muted red fg |

no background colors on lines - just the sign symbol color.

## .minimap (neominimap)

minimap shows git changes as background-colored regions.

| state | add | change | delete |
|-------|-----|--------|--------|
| unstaged | bright pastel green bg | bright pastel yellow bg | bright pastel red bg |
| staged | muted green bg | muted yellow bg | muted red bg |

unstaged = needs attention = brighter
staged = already handled = muted

## .color values (desert theme)

| tone | green | yellow | red |
|------|-------|--------|-----|
| bright (unstaged) | `#5a7a5a` | `#7a7a5a` | `#7a5a5a` |
| muted (staged) | `#4a5a4a` | `#5a5a4a` | `#5a4a4a` |
