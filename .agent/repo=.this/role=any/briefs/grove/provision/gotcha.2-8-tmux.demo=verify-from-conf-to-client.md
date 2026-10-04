# gotcha.2-8-tmux.demo=verify-from-conf-to-client

## .what

the dated measurements behind `2.8.tmux/configure.verify.sh` and the live-server claims it
calls in `_.sh`. the verify grades FOUR surfaces, each read at a different moment, and a ✔ on
one says no word about the next:

| surface | read when | the claim |
|---|---|---|
| the conf on disk | the NEXT server starts | 1-5 |
| a live server | its own start, held in memory | m6, m7 |
| a live pane | its spawn, held for life | m8 |
| an attached client | its attach, never again | m9 |

## m1 — the conf is DIFFED, and the plugin list is READ from it

- a stale conf exists, loads, and is an older revision. the symptom is "my keybind change had
  no effect", which a human blames on tmux
- the conf's `@plugin` lines ARE the declaration. a list here is a second copy, free to drift the
  first time a plugin lands in the conf and not here
- an absent plugin is a ✋, never a 🌙: tmux starts, the conf loads, and the plugin's keybinds and
  status segments are omitted with no error anywhere. the human finds it by a dead key

## m2 — a SECOND conf loaded after ours, this laptop 2026-07-30

- tmux 3.4 reads a LIST of confs, in order, and a later file wins. `#{config_files}` answered:
  ```
  /home/vlad/.tmux.conf,/home/vlad/.config/tmux/tmux.conf
  ```
- claim 2 had just reported `~/.tmux.conf matches the checkout ✔`, correctly. the XDG conf loads
  AFTER it and differed from the checkout, so it won every option both name
- ⇒ a true answer to a question that is no longer the whole question
- it REPORTS and never deletes: a shadow conf is a human's real config, and which path the repo
  should own carries a human's preference. a wrong guess deletes work

## m3 — the default socket alone went blind, a cloud grove 2026-09-13

- a bare `tmux display-message` speaks to the `default` socket only, and a box whose ducts are
  tmux often has no server there
- the row printed "no tmux server answered" in the same output where the row below it read TWO
  live servers: one set, two readers, and only the default-only one went blind
  (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.9)
- ⇒ every socket is asked, and the FIRST to answer settles it: `#{config_files}` is a property of
  the conf on disk, so any live server reports the same list
- each ask is `timeout`-bounded: a server wedged on a hung pane never replies, and a bare call
  would block a `--mode plan` forever (`rule.require.bounded-probes-in-verifies`)

## m4 — the `A…Z` sentinel, a cloud grove on tmux 3.2a, 2026-09-13

`#{config_files}` lands in tmux 3.3. an older tmux answers and expands the format to empty, so a
bare read cannot part three states that all arrive empty:

| `A#{config_files}Z` reads | means |
|---|---|
| empty | no server answered — the claim cannot be observed |
| exactly `AZ` | it answered; the format is unsupported, or no conf loaded |
| `A<list>Z` | the list, authoritative |

- 📜 `display-message -p 'ALIVE'` printed `ALIVE` and the sentinel printed `AZ`: the server was
  reachable the whole time, and the old row said "no tmux server answered" — a TRUE verdict
  with the wrong SUBJECT named (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.4)
- an old tmux falls back to a FILE test of the XDG path, the one m2 names. a decline would
  report no shadow at all, so a keybind would land, verify green, and be overridden
- ⚠️ the file test is WEAKER and its output says so. tmux's search order is NOT re-derived
  here — that list is version-dependent and free to drift from tmux itself
- the client claim (m9) wraps its own format the same way, for the same reason

## m5 — `while read` dropped the LAST element, this laptop 2026-07-30

- `while read` returns non-zero at EOF, so a final line with no newline is read and dropped
- the list was `<managed>,<shadow>`, so the dropped element was always the shadow — the one item
  the claim exists to find. it reported "the only conf tmux loads ✔" where `#{config_files}`
  named two
- it fails OPEN on exactly the input that matters, and a single-conf box parses right
  (`rule.forbid.failhide`; the same family as `gotcha.pipefail-grep-q`)
- ⇒ `printf '%s\n'` feeds the loop: the newline at its end carries the claim. the ✔ prints the
  list it read, so a reader can tell a real ✔ from a misread one

## m6 — `default-terminal` at `screen` beside a correct RGB line, grove-ahbode-v20260901 2026-09-03

- `default-terminal` sets the TERM every pane inherits at spawn. tmux's built-in default is
  `screen`, 8 colours, so an app inside emits 8-colour codes and no option downstream recovers
  what it never sent
- the box had `terminal-features …:RGB` right and `default-terminal` at `screen`: the outward path
  fixed, the source still clamped. a reader who saw only the RGB line called the conf converged
- the name is READ from the conf, as m1 reads the plugin list
- an absent `infocmp` is a 🌙: it ships in ncurses-bin, which `4.3.1.terminfo` owns, and 4.x runs
  after 2.x — so a first apply may legitimately lack it
- the SERVER twin of this claim reads each live server's own value: a server started before the
  conf, or with `-f` elsewhere, still holds `screen`

## m7 — a removed plugin still ran in every live server, 2026-09-13

the source measurement is `gotcha.2-8-tmux.demo=plugin-root-and-two-readers`, m7. the verify's half:

- 118 concurrent `continuum_save.sh` at 543% cpu, fired by the `status-right` interpolation the
  live duct server still held, after the `@plugin` line was cut
- `status-right` is the one option read: a status-segment plugin installs its `#(…)` there, and
  tmux evaluates it each `status-interval` — the interpolation IS the timer
- an unreachable socket is a 🌙: a socket file outlives its server, and a corpse runs no timer. a
  ✋ per corpse would cry wolf on every box with a stale socket

## m8 — a pane keeps its spawn-time TERM, and the only fix-text was a keystroke, 2026-09-13

- `default-terminal` is consumed ONCE, at pane spawn, into the child's environment. a source that
  repairs the server repairs no extant pane, so a box can pass conf, server and client claims and
  still render 8 colours in every older pane
- `/proc/<pid>/environ` is read, never a tmux format: tmux exposes the SESSION environment, and
  only the child's own copy is what the app read. linux-only; a pane that exits mid-read or a
  foreign process that denies the read is a 🌙
- 📜 a fresh grove: the claim bit with `1 of 1 live pane(s)`, and its sole fix-text was `prefix c`.
  a grove's only affected pane is the DUCT's own, and no human sits there
- ⇒ a ✋ no one can clear is the one that gets silenced, so the fix-text names `duct.reboot`
  beside the keystroke (`rule.require.one-command-provision`, its unrepairable-fix-text clause)

## m9 — every claim green, colour broken, this laptop 2026-09-13

- the colour contract has two halves, read at two moments:
  ```
  default-terminal    a SERVER option, read when a PANE spawns
  terminal-features   read when a CLIENT ATTACHES, and never again
  ```
- the conf was sourced into 19 live servers, the verify printed ✔ on every claim, and the human
  reported broken colour in the same minute. the apply named the reattach in prose, and a
  caveat no one re-reads is indistinguishable from an absent one
- the symptom is a DOWNSAMPLE: the client was never flagged RGB, so tmux quantises each 24-bit
  colour to a palette it believes is 8/16 — orange reads red, red reads purple
- the wanted set is the conf's own `set -as terminal-features` lines, never a list here
  (`rule.require.identical-bundle-composition`). a client whose TERM the conf never names is not
  graded: the conf declares per-term (`xterm-kitty:RGB`)

## m10 — the shadow came back, and the wheel scrolled shell history, this laptop 2026-10-02

- the m2 shadow (`~/.config/tmux/tmux.conf`, last written 2026-07-22) still sat on disk and still
  loaded AFTER ours. it set `mouse off`, so every live server ran with the mouse off
- the symptom read as a reversed scroll: with tmux off the mouse, kitty turns the wheel into
  arrow keys, and the shell answers an arrow with its command history
- the human decreed: **there can only be one**. the upsert now MOVES each shadow aside to
  `<path>.bak.<stamp>` (`_shadow_confs` in `_.sh` lists them). m2's fear held — a shadow may hold
  a human's work — so it is moved, never deleted, and the apply prints where it went
- ⚠️ a live server's `#{config_files}` is fixed at its START: after the move it still NAMES the
  retired path. claim 3 grades only a shadow still ON DISK as ✋; a retired one is a 🌙, since an
  option that only it set lingers in that server until it restarts

## .see also

- `2.8.tmux/configure.verify.sh` — claims 1-5, the conf on disk
- `2.8.tmux/configure.upsert.sh` — m10's retirement of each shadow conf
- `2.8.tmux/_.sh` — `_verify_live_servers`, m6-m9's live claims
- `gotcha.2-8-tmux.demo=plugin-root-and-two-readers` — the plugin root, the socket inventory, the source
- `gotcha.a-check-that-cries-wolf-gets-silenced`, `rule.require.bounded-probes-in-verifies`
