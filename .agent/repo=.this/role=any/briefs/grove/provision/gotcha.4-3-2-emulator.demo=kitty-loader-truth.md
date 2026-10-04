# gotcha.4-3-2-emulator.demo=kitty-loader-truth

## .what

the dated measurements behind `4.3.2.emulator/configure.verify.sh`: why presence is not
correctness, why kitty's own loader is the only truthful reader of its conf, and the exact
values that loader resolves.

## m1 — presence is not correctness

grove-1, 2026-07-29: `~/.tmux.conf` existed on disk and tmux still refused a kitty client.
`[[ -f kitty.conf ]]` passes on every broken config ever written — a file's presence says no
word about its content.

## m2 — a verify that re-asserts its own trigger loops forever

grove-1, 2026-07-30: a verify demanded `allow_remote_control` be a GRANT and exited 1
forever. its own fix line named the apply that had just written the value it rejected — the
verify's claim contradicted the upsert's design (opt-in per terminal, `no` in the file).

## m3 — kitty 0.47.4's `load_config`, one fixture per value

| written | resolved | what it grants |
|---|---|---|
| `no false n` | verbatim | remote control disabled |
| `socket-only` | verbatim | socket requests accepted unconditionally |
| `socket` | verbatim | socket unconditional; tty by password |
| `password` | verbatim | both channels, password-gated |
| `yes true y` | verbatim | always accepted, socket and tty |

a `== "yes"` deny has two holes: the loader returns `true`/`y` verbatim (hole 1), and
`socket`/`socket-only` accept socket requests with no confirm (hole 2) — an allowlist of the
three disabled spellings is the only safe read.

## m4 — last assignment wins, include resolves in place

2026-08-31, kitty 0.47.4's `load_config` over three fixtures:

| file | resolves to |
|---|---|
| `no`, then `yes`, one file | `yes` — `head -1` would answer `no` |
| `include(yes)`, then `no` | `no` |
| `no`, then `include(yes)` | `yes` — a text reader sees no include |

kitty resolves the LAST assignment and resolves `include` IN PLACE. `tail -1` closes the
first fixture and not the third. `globinclude`/`envinclude` widen it further — asking kitty
avoids a second holder of its grammar (rule.forbid.two-writers-on-one-artifact).

## m5 — seen to discriminate, two readers side by side

2026-08-31, kitty's loader vs. a retired text-grep reader:

| fixture | kitty resolves | text-grep resolved |
|---|---|---|
| one line, `no` | `no` | `no` |
| `no` then `yes` | `yes` | `no` ← flipped |
| `no` then `include(yes)` | `yes` | `no` ← flipped |
| one line, `socket-only` | `socket-only` | `socket-only` |

the two flips are the whole defect; the two agreeing rows are what make the flips legible.

## m6 — seen to discriminate, the whole declared set

2026-09-01, the set is read from kitty's own option definition, never a list in this repo:

| value | verdict | grants |
|---|---|---|
| `false n no` | pass ✔ | remote control disabled |
| `password` | flag ✔ | both channels, password-gated |
| `socket socket-only` | flag ✔ | socket unconditional |
| `true y yes` | flag ✔ | always accepted, socket and tty |
| a value kitty does not declare | flag ✔ | unread is not a pass |

## m7 — `--debug-config` is not a real flag

2026-08-31: kitty 0.47.4 rejects `--debug-config` as an unknown flag. a row built on it would
print "parse unproven" on every box, forever — a row that never settles trains its reader to
stop reading it (gotcha.a-check-that-cries-wolf-gets-silenced, m13).

## m8 — the shape `load_config(accumulate_bad_lines=…)` reads

2026-08-31:

| input | bad lines | warning |
|---|---|---|
| a clean conf | 0 | none |
| a bad value for a real key | 1, with the `ValueError` | none |
| an unknown key | 0 | `Ignoring unknown config key: …` |
| a `map` to an unknown action | 0 | none |

a bad value and an unknown key arrive by different routes, so both must be read. a `map` to
an unknown action binds lazily and fails at the keystroke, never at load — the parse claim
covers only what kitty reads at load time.

## m9 — seen to discriminate, the parse reader driven verbatim

2026-08-31:

| fixture | want | got |
|---|---|---|
| a clean conf | GREEN | GREEN |
| a bad value for a real key | RED | RED |
| an unknown key | RED | RED |
| a `map` to an unknown action | GREEN | GREEN — the lazy-bind bound above |

the fourth row asserts the limit rather than assumes it; a row never seen to redden on a
break nor green on a pass does no work.

## m10 — the claims a stale or unread conf still passes

the verify's claims 1b-1d, each a gap the property claims (2-5) cannot see:

| claim | the gap it closes |
|---|---|
| 1b | kitty prefers `KITTY_CONFIG_DIRECTORY` over `~/.config/kitty`; a shell rc, a `.desktop` Exec or a systemd unit can export it, and then claims 2-5 describe a conf that shapes no terminal |
| 1c | the deploy is a plain `cp`, so a byte-diff is decisive; all five property claims hold on a stale copy |
| 1d | a byte match says no word of whether python accepts the kitten. kitty loads a kitten LAZILY, at its first keypress, so a syntax error reaches a HUMAN mid-task as a dead key, the same shape a wrong gate has. it is read with kitty's own interpreter, since the box may carry no system python3 |
| 3 | an absent kitten fails at KEYPRESS, never at startup, so ctrl+c does no copy three layers from the absent file (rule.require.seam-claims-have-an-owner) |
| 3b | `notify-send`: the upsert owns the PACKAGE, and the CALL in `copy_notify.py` has no owner; it fails mid-copy on a stripped box |

## m11 — `remember_window_size` defaults to yes, and outranks the declared size, 2026-09-03

- a 6-tree fleet held zero windows at the declared size; the worst was 27 cols, narrow enough
  to wrap claude's modal chrome, so a stall detector keyed on it read a live modal as an idle box
- ⇒ size had become cached state, the inversion the bundle exists to stop
  (rule.require.judge-declared-state-not-live-state)
- the claim reads the LOADER for m4's two reasons, and a twin claim (2d) asks whether the
  conf STATES it, as 2b does for claim 2: what kitty resolves today can be a default that a
  release flips with no diff here

## m12 — the default-terminal claim was deleted and restored the same minute, 2026-09-03

- the human ruled it MANDATORY: *"kitty is the default-terminal, that must be mandatorily
  enforced"*. ptyxis held the selection on the laptop, so a ✋ there is CORRECT until the box is
- *"drop ptyxis"* was read as "drop the claim about ptyxis": the reader that CATCHES the defect
  was removed, and the defect kept
- the deletion cited `gotcha.a-check-that-cries-wolf-gets-silenced`, which says the opposite: a
  check that reddens on a REAL defect is the one kind never to silence

## m13 — the bundle applies to EVERY machine, headless included

the old argument was "kitty is a gpu emulator, it opens a window, so a headless box declines
rather than install ~30MB it could never use". it is wrong twice over:

1. it confuses RUN with HOLD. the tarball extracts on any linux box; only `kitty` the window
   needs a display. its peer `4.3.1.terminfo` already proved the intuition inverts here — the
   box that needs the `xterm-kitty` entry is the box a kitty client CONNECTS TO, the headless one
2. it would deny a grove `kitten`, which the tarball ships beside kitty. every termwork skill
   drives `kitten @`, so a decline takes a capacity the grove uses — the very capacity kitty was
   chosen over the flatpak build to get

⇒ NO early return, and the 30MB is worth it (rule.require.identical-bundle-composition)

## .see also

- `4.3.2.emulator/configure.verify.sh` — the claims these measurements back
- `4.3.2.emulator/_.sh` — m13's header
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m13, the never-settles trap m7 avoids
- `rule.forbid.two-writers-on-one-artifact` — why kitty's own loader reads, not a re-spelled grammar
- `gotcha.pipefail-grep-q` — the `grep -q` SIGPIPE trap the parse-complaint capture avoids
