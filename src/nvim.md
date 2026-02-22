# nvim

neovim config with desert theme, file management, and vim-friendly keybinds.

## keybindings

### navigation

| key | action |
|-----|--------|
| `Ctrl+h/j/k/l` | move between windows |
| `Alt+h/j/k/l` | resize windows |
| `Ctrl+e` | toggle/focus neo-tree |
| `-` | open parent directory in oil |

### edit

| key | action |
|-----|--------|
| `Ctrl+s` | save file |
| `Ctrl+z` | undo |
| `Ctrl+Shift+z` | redo |
| `Ctrl+c` | copy (visual mode) |
| `Ctrl+v` | paste |
| `Ctrl+r` | copy relative file path to clipboard |

## file management

two complementary tools for different workflows:

### neo-tree (sidebar browser)

open with `Ctrl+e`. use for:
- browse project structure
- quick navigation to known files
- git status overview

| key | action |
|-----|--------|
| `Enter` | open file / toggle directory |
| `a` | add new file |
| `d` | delete |
| `r` | rename |
| `y` | copy file |
| `m` | move/cut file |
| `p` | paste |
| `o` | open directory in oil |

### oil (edit directories as buffers)

open with `-` or `o` from neo-tree. use for:
- bulk file operations (rename, move, delete)
- create multiple files at once
- duplicate files

workflow:
1. press `-` to open current directory as a buffer
2. edit like normal text:
   - `yy` + `p` = duplicate file
   - `dd` = delete file
   - `o` + type name = create file
   - edit text = rename file
3. `:w` to apply — confirmation popup shows changes

oil is safe by default — deletes always show confirmation.

## plugins

| plugin | purpose |
|--------|---------|
| lazy.nvim | plugin manager |
| neo-tree | sidebar file tree |
| oil.nvim | edit directories as buffers |
| smart-splits | window navigation + resize |
| lualine | status line |
| gitsigns | git indicators in gutter |

## theme

desert palette from [gogh](https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml) — warm earth tones on dark background. matches ptyxis terminal and gitui configs.
