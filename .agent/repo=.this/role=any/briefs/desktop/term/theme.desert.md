# desert theme

## .origin

the Desert palette comes from the [Gogh](https://github.com/Gogh-Co/Gogh) terminal color scheme collection. Gogh provides curated 16-color palettes for terminal emulators. the Desert palette is one of its schemes, designed for warm, muted tones on a dark background.

- ref: https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml

## .philosophy

warm earth tones on a dark neutral background. high contrast where it matters (foreground text, errors), soft contrast for secondary elements (comments, line numbers). the palette avoids harsh neon colors in favor of sandy, wheat, and gold tones — evocative of a desert at dusk.

## .spec

### terminal colors (16-color)

| slot | name | hex | role |
|------|------|-----|------|
| 0 | black | `#4D4D4D` | dim text, comments |
| 1 | red | `#FF2B2B` | errors, deletions |
| 2 | green | `#98FB98` | success, strings, additions |
| 3 | yellow | `#F0E68C` | keywords, search highlights |
| 4 | blue | `#CD853F` | preprocessor, paths |
| 5 | magenta | `#FFDEAD` | numbers, constants |
| 6 | cyan | `#FFA0A0` | identifiers, special |
| 7 | white | `#F5DEB3` | operators, secondary text |
| 8 | bright black | `#555555` | selection bg, borders |
| 9 | bright red | `#FF5555` | bright errors |
| 10 | bright green | `#55FF55` | bright success |
| 11 | bright yellow | `#FFFF55` | bright highlight |
| 12 | bright blue | `#87CEFF` | functions, titles, folders |
| 13 | bright magenta | `#FF55FF` | bright accent |
| 14 | bright cyan | `#FFD700` | types, gold accent |
| 15 | bright white | `#FFFFFF` | foreground, cursor |

### interface colors

| element | hex |
|---------|-----|
| background | `#333333` |
| foreground | `#FFFFFF` |
| cursor | `#FFFFFF` |

## .consumers

### ~~ptyxis terminal~~ — retired 2026-08-13

ptyxis was this palette's first consumer, and it referenced the theme **by name**
(Gogh ships Desert built in), so the hexes below were never written anywhere on
its account. it was deleted with its bundle when this box went 100% kitty.

⚠️ what its removal does NOT change: the hexes above are the palette's record,
and kitty + neovim below each declare them explicitly. a consumer that names a
palette by reference contributes no definition, so its departure takes none.

### neovim

- applied via: `src/init.lua` (synced by `grove.provision.nvim`)
- method: custom highlight groups set with `vim.api.nvim_set_hl()` — no external theme plugin
- location: `~/.config/nvim/init.lua`
- color map:
  - bg → `#3B2F27`, fg → `#FFFFFF`
  - comments → `#4D4D4D` (dim, italic)
  - strings → `#98FB98` (green)
  - keywords/statements → `#F0E68C` (yellow)
  - functions → `#CD853F` (brown/peru)
  - identifiers → `#FFA0A0` (pink)
  - numbers/constants → `#FFDEAD` (peach)
  - types → `#FFD700` (gold)
  - preprocessor → `#CD853F` (brown)
  - errors → `#FF2B2B` (red)
