# demo: 4.3.2.emulator — the terminfo absence, measured once

## .what

`4.3.2.emulator/provision.upsert.sh` installs no xterm-kitty terminfo entry — that claim
belongs to `4.3.1.terminfo`. one measurement backs the split.

## m1 — one absent entry read as three unrelated complaints, grove-1 2026-07-29

- grove-1 shipped with no xterm-kitty terminfo entry. the fallout read as three separate
  defects: "tmux not usable", "core utils broken", "backspaces render as spaces"
- ⇒ all three traced to the one absent entry; `4.3.1.terminfo` owns the fix. a local box
  satisfies the claim for free — the tarball ships the entry beside the binary

## .see also

- `4.3.2.emulator/provision.upsert.sh` — the header this measurement backs
- `4.3.1.terminfo` — the bundle that owns the terminfo claim
