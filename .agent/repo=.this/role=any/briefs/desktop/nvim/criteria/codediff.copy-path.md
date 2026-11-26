# codediff copy path

## .what

criteria for ctrl+r / ctrl+alt+r / ctrl+super+r (copy relative path) inside a codediff tab.

## usecases

### usecase.1 = a file row in the explorer tree

given('cursor is on a file row in the codediff explorer')
  when('user presses ctrl+alt+r')
    then('the clipboard holds that file path, relative to cwd')
    then('never the explorer buffer label `CodeDiff Explorer [N]`')

### usecase.2 = a directory row in the explorer tree

given('cursor is on a directory row in the codediff explorer')
  when('user presses ctrl+alt+r')
    then('the clipboard holds that directory path, relative to cwd')

### usecase.3 = a revision pane

given('cursor is in a codediff pane that shows a git revision (`codediff:///<root>///<rev>/<path>`)')
  when('user presses ctrl+alt+r')
    then('the clipboard holds <path> relative to cwd')
    then('never the virtual buffer name, and never `<rev>/<path>`')

### usecase.4 = an ordinary buffer is unchanged

given('cursor is in a regular file buffer')
  when('user presses ctrl+alt+r')
    then('the clipboard holds `%:.`, as before')

### usecase.5 = an image-diff pane

given('cursor is in either pane of a codediff image diff (before or after)')
  when('user presses ctrl+r, ctrl+alt+r, or ctrl+super+r')
    then('the clipboard holds the image file path, relative to cwd')
    then('never empty, and never the temp file the before side renders from')

### usecase.6 = an image opened directly

given('cursor is in an image buffer opened via `nvim path/to/x.png`')
  when('user presses ctrl+alt+r')
    then('the clipboard holds that image path, relative to cwd')

## .invariant

> **every buffer that SHOWS a file copies that file's path.** a buffer whose own name
> is not the file — a label, a virtual url, an unnamed scratch pane — records the
> file it stands for, and the one resolver reads that record first.

## .why

a codediff buffer's own name is a label, never the file. measured 2026-10-08:
ctrl+alt+r over a file in the tree copied "CodeDiff Explorer [2]". measured
2026-10-25: an image-diff pane is an unnamed scratch buffer, so the same keys
copied an empty path.

## boundaries

- explorer paths are relative to the explorer's git root; a revision pane's URL carries its own
  root, read by codediff's `parse_url`. either is then made relative to cwd
- an image-diff pane records `b:image_diff_path` (the repo file, never the temp blob) before
  any render, so a failed render still copies
- one resolver (`get_codediff_abspath` in init.lua) serves all three key variants
- clamp: `prove.codediff-copy-path`
