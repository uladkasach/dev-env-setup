# F11 — `--output keys` prints its key lines at column 0, where the meter is read

## .the fork

peer round i002 of 5.3 (r006 nitpick.1) saw `OWED=` / `BLOCKED=` / `DAMAGED=` at column 0 mid-tree
in the `--output keys` renders, and asked to indent them under a label, or move them after the tree.

- **indent or label them** — a tidier tree, and the boot's parser must learn the indented form
- **move them to the end** — but a later refusal (no crew tree, no `rhx` on the box) exits before
  the end, and then the keys never print: the boot would read "could not be read" over a meter
  that WAS read
- **column 0, where the meter is read** — the boot's reader takes the first line whose field 1 is
  the key (`awk -F= '$1 == "OWED"'`); a key at column 0 can never be mistaken for prose

## .taken

column 0, at the read. `--output keys` is the boot's channel, never a human's; the human render is
the same command with no flag, which prints no keys. the snapshot holds them because every variant
a caller can meet is snapped.

## .rework

clean: a label line and a two-character change to the boot's awk.

## .confidence

85%.

## .where

`.agent/repo=.this/role=any/skills/git.grove.auth.commit.set.sh` (the keys print once the meter is
read); `git.grove.provision.boot.operations.sh` (`boot_commit_grant_read`).

## .verdict

moot 2026-11-22 (seed S5): the grant skill and its `--output keys` are removed.
