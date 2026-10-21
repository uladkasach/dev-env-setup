# F1 — lock by mode `0444`, not `chattr +i`

- **fork**: `0444` (no root, stops `open`-for-write, not `rename` or `chmod`) vs `chattr +i` (stops all three, needs root on every lock and unlock)
- **taken**: `0444`. the measured writer opens the file through the arrow (the arrow survives), so `0444` stops it. `chattr` would make every 5.3.brains apply owe `sudo -v &&`, against the one-command bar
- **rework**: clean — the owner's write path is one internal function (locked tmp → rename). under
  `chattr +i` the rename fails too, so that function would gain a `sudo chattr -i` / `+i` pair
- **side benefit of `0444`**: the owner never needs the file writable — a rename needs only the dir —
  so there is no unlock window for a race or an interrupt (cases 5, 7)
- **confidence 80%, low because**: an unknown future writer may rename rather than open
- **where**: `5.3.brains/configure.upsert.sh`, the owner's write function (locked tmp → rename)
- **verdict**: open
