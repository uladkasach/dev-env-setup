# keyboard alt/super position, per board

## .what

the key beside the spacebar is **super** on every board, and the key one further out is **alt**.

- a pc-layout board puts alt beside the spacebar, so it swaps
- an apple-layout board already puts cmd (super) there, so it does not
- ⇒ the swap is a fact about the BOARD, never about the box

## usecases

### usecase.1 = the builtin laptop board

given('the builtin board, a pc layout: [ctrl][fn][super][alt][space]')
  when('the human presses the key beside the spacebar + a letter')
    then('the compositor receives super + that letter')
  when('the human presses the key one further out + a letter')
    then('the compositor receives alt + that letter')

### usecase.2 = an apple magic keyboard

given('an apple board: [ctrl][option][cmd][space]')
  when('the human presses cmd (beside the spacebar) + a letter')
    then('the compositor receives super + that letter')
  when('the human presses option + a letter')
    then('the compositor receives alt + that letter')

### usecase.3 = both boards connected at once

given('the builtin and an apple board are both live')
  when('the human types on either')
    then('each board follows its own usecase above, with no toggle')
    then('no command, alias, or reconnect is needed to switch')

### usecase.4 = a new apple-layout board

given('a board whose id is not yet declared')
  when('the human runs `rhx input.keyboard.ids`')
    then('it lists the board with its vendor:product id')
    then('it names the conf that claims it — default.conf, so it swaps')
  when('the id is added to KEYBINDS_APPLE_IDS and the bundle is applied')
    then('the board is claimed by apple.conf, and does not swap')

## boundaries

- the swap lives in keyd (`1.1.keybinds`), the one layer that knows which device a key came from
- `default.conf` matches `*` minus the apple ids; `apple.conf` matches the apple ids only
  - ⇒ each board matches exactly one conf, so read order decides naught
- both confs carry the full shared remap (capslock, vimarrows, noop keys)
  - keyd applies one conf per device, so a key absent from a conf is simply unmapped there
- cosmic's xkb options carry NO alt/super swap
  - 📜 `altwin:swap_lalt_lwin` lived there behind `use.keymap.altswap` / `altboot`
  - xkb options apply to every keyboard at once, so the swap was right for the builtin
    and backwards for the apple board — the defect this criteria replaced
  - stacked on keyd's swap, it would double-swap the builtin back to stock
- the apple ids are declared once, in `1.1.keybinds/_.sh`; the skill and both phases read it

## the shared remap, line by line

`_.sh` renders both confs (`keybinds_keyd_conf`), so the upsert and the verify share one source.

- `capslock = overload(control, esc)`: held is ctrl, tapped is escape. capslock is the largest key
  nearest the pinky, and its stock function is used by nobody
- `overload_tap_timeout = 200` drops the tap-escape after 200ms of hold. without it, a slow
  ctrl+click emits a stray escape that nvim reads as a mode change
- `coffee / sleep / suspend / power = noop`: these sit near the arrow cluster, and a misfire there
  suspends the box mid-work. `1.2.power` blocks the same acts at the systemd layer. this blocks them
  at the DEVICE layer, the only layer that catches a key that never reaches logind
- `rightalt / rightcontrol / rightmeta = layer(vimarrows)`: rightalt on a laptop, rightcontrol on
  the hhkb, rightmeta on an apple magic keyboard. all three are declared because one human moves
  between all three boards

## why the upsert empties `/etc/keyd/` first

- keyd reads EVERY `.conf` in `/etc/keyd/`
- a stray file that also matches `*` would fight `default.conf` by read order
- a rename of the conf in a past revision would leave its old copy live
- ⇒ the dir is emptied and re-declared (`rule.require.judge-declared-state-not-live-state`)

## why keynav starts from `~/.profile`, never a systemd user unit

- keynav needs a live X/wayland session to attach to
- `~/.profile` is read at login, when that session exists
- a boot-time unit would start before it and exit

## see also

- `rhx input.keyboard.ids` — list boards, their ids, and which conf claims each
- `src/grove.provision/1.system/1.1.keybinds/` — the bundle that holds the declaration
- `howto.fix-apple-magic-device-bluetooth` — when the apple board will not connect at all
