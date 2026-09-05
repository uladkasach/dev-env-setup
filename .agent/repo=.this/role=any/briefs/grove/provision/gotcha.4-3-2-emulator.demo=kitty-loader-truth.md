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

## .see also

- `gotcha.a-check-that-cries-wolf-gets-silenced` — m13, the never-settles trap m7 avoids
- `rule.forbid.two-writers-on-one-artifact` — why kitty's own loader reads, not a re-spelled grammar
- `gotcha.pipefail-grep-q` — the `grep -q` SIGPIPE trap the parse-complaint capture avoids
