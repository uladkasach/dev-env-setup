# gotcha: keyd's start hangs while a magic keyboard is connected

## .what

keyd 2.5.0, at **start**, waits until every key on every board reads released (an `EVIOCGKEY`
loop). the apple magic keyboard (`004c:029c`) reports `BTN_0` as held, always. so a keyd that
starts while that board is connected spins at 100% of one core, forever, and grabs **no**
keyboard — every remap goes dark: caps→ctrl, the alt/super swap, all of them.

| path | waits for release? | safe with a magic keyboard connected? |
|---|---|---|
| `systemctl restart keyd` | ✔ yes | ✋ **no** — hangs |
| boot with the board on | ✔ yes | ✋ **no** — hangs |
| hotplug (board connects after keyd is up) | ✗ no | ✔ yes |
| `keyd reload` | ✗ no | ✔ yes |

## .why a peer's box did not show it

the same bundle on a peer's box ran fine — that box had no magic keyboard connected when keyd
started. the defect sits in the board × the start path, never in the bundle's config.

## .measured — 2026-10-19

after a `1.1.keybinds` apply, which then restarted keyd, caps lock no longer acted as ctrl on any
board. keyd's MainPID burned a full core; `/proc/<pid>/stat` utime+stime rose ~CLK_TCK per
second. magic keyboard off → `sudo systemctl restart keyd` → board on: every remap returned.

## .what the repo does about it

- `1.1.keybinds` upsert runs `sudo keyd reload` on a live keyd, and `restart` only when keyd is
  down
- `1.1.keybinds` verify samples keyd's cpu for 1s; above half a core it reports `keyd is stuck`
  with the fix: board off, `sudo systemctl restart keyd`, board on

## .enforcement

- a bundle or fix-text that restarts a live keyd = **blocker**; reload it
- a caps-lock latch left by the hang: `sudo -v && rhx input.keyboard.capslock.off`

## .see also

- `criteria/keyboard.alt-super-per-board` — the per-board swap this hang silenced
