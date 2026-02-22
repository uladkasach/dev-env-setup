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

## git

`Ctrl+g` opens **gitdiff.tab** — a dedicated tab with two panes:
- **gitdiff.pane.tree** — file tree with changed files (left)
- **gitdiff.pane.file** — diff content for selected file (right)

| key | context | action |
|-----|---------|--------|
| `Ctrl+g` | anywhere | toggle between gitdiff.tab and file tabs |
| `Ctrl+h/j/k/l` | gitdiff.tab | navigate between panes |
| `Enter` | gitdiff.pane.tree | view diff in gitdiff.pane.file |
| `o` | gitdiff.pane.tree | open file and close gitdiff.tab |
| `o` | gitdiff.pane.file | open file in new tab (keeps gitdiff.tab) |
| `Ctrl+d s` or `a` | anywhere / gitdiff.pane.tree | stage file/buffer |
| `Ctrl+d u` | anywhere / gitdiff.pane.tree | unstage file/buffer |
| `Ctrl+d x` | anywhere / gitdiff.pane.tree | discard unstaged changes |
| `Ctrl+d j` / `Ctrl+d k` | anywhere | next / prev diff boundary |

workflow:
1. `Ctrl+g` to open gitdiff.tab
2. navigate gitdiff.pane.tree to find changed files
3. `Enter` to view diff in gitdiff.pane.file
4. `o` in gitdiff.pane.file to open file in new tab (gitdiff.tab stays open)
5. `Ctrl+g` to bounce back to gitdiff.tab
6. `Ctrl+d a` / `Ctrl+d x` to stage/unstage/discard
7. `o` in gitdiff.pane.tree to open file and close gitdiff.tab when done

## plugins

| plugin | purpose |
|--------|---------|
| lazy.nvim | plugin manager |
| neo-tree | sidebar file tree |
| oil.nvim | edit directories as buffers |
| smart-splits | window navigation + resize |
| lualine | status line |
| gitsigns | git indicators in gutter |
| diffview | git diff view with file tree |

## theme

desert palette from [gogh](https://github.com/Gogh-Co/Gogh/blob/master/themes/Desert.yml) — warm earth tones on dark background. matches ptyxis terminal and gitui configs.
