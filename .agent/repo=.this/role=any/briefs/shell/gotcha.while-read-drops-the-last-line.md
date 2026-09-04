# gotcha: `while read` drops a final line with no newline after it

## .what

`read` returns **non-zero at EOF**. so when the last line of its input has no
newline after it, `read` sets the variable *and* reports failure — and `while`
ends the loop **before the body runs**. the last element is read, then discarded.

```sh
# 👎 the last element never reaches the body
while IFS= read -r one; do
  items+=("$one")
done < <(printf '%s' "$list" | tr ',' '\n')

# 👍 the newline is what lets the final iteration run
while IFS= read -r one; do
  items+=("$one")
done < <(printf '%s\n' "$list" | tr ',' '\n')
```

`printf '%s'` emits no newline. `printf '%s\n'`, `echo`, and a here-string
(`<<< "$list"`) all do.

## .why it is worse than an ordinary off-by-one

it **fails open**, and it fails open on precisely the input that matters.

- a **one-element** list yields an empty result — which, for a "find the extras"
  check, is the right answer by accident
- a **two-element** list silently becomes one

so a check written this way looks correct on every simple box, and misreports on
exactly the complex box it was written for.

## .the measurement — 2026-07-30

`2.8.tmux/configure.verify.sh` asks tmux which config files it loads, then
subtracts the one this repo manages; whatever remains is a **shadow conf** that
overrides it. tmux answered:

```
/home/<user>/.tmux.conf,/home/<user>/.config/tmux/tmux.conf
```

the shadow is the **last** element, always — the managed conf loads first. so the
one element the parse dropped was the only one the check existed to find. it
printed:

```
• ~/.tmux.conf is the only conf tmux loads ✔
```

on a box that read two confs, one of which overrode the repo's every option.

only one change caught it: the ✔ line began to print the *observed list* beside
the verdict. list and verdict then contradicted each other on screen, in one
line. without that, the ✔ is indistinguishable from a true one.

## .the lesson beyond the newline

**print what you observed, not only what you concluded.** a verdict is only as
trustworthy as the input it read, and a reader who cannot see that input cannot
tell a real ✔ from a misread one.

```sh
# 👎 the verdict alone — a reader cannot falsify it
echo "   • ~/.tmux.conf is the only conf tmux loads ✔"

# 👍 the verdict beside its evidence — a contradiction is visible at a glance
echo "   • ~/.tmux.conf is the only conf tmux loads ✔ ($loaded)"
```

## .the family it belongs to

three shell idioms in this repo share one failure mode, a **false ✔**:

| idiom | the trap |
|---|---|
| `grep -q` in a pipeline under `pipefail` | early exit SIGPIPEs the producer → 141 → reads as "no match" (`gotcha.pipefail-grep-q`) |
| `printf '%s'` into `while read` | final element read, then dropped at EOF |
| `[[ -e "$link" ]]` on a symlink | follows the link, so a broken one reads as absent |

each is idiomatic, each looks right, and each turns a real defect into a green
line. when a check has never gone red, suspect the check before you trust it.

### the mirror family — a false ✋

the three above are all **false ✔**. their mirror is the **false ✋**: a check that
goes red against a subject that plainly works. it is the more corrosive of the
two, because a human who catches it in a lie will silence it — and a silenced
check is a false ✔ with extra steps. see
`gotcha.a-check-that-cries-wolf-gets-silenced`.

## .the test

> does my loop's input end with a newline?

- `printf '%s\n'`, `echo`, `<<<`, a real file → yes, safe
- `printf '%s'`, or a command whose output lacks a final newline → **the last
  element is lost**

when unsure, prefer a here-string: `done <<< "$list"` always terminates properly.

## .see also

- `gotcha.pipefail-grep-q` — the same false-✔ outcome, a different idiom
- `rule.forbid.failhide` — why a check that fails open is worse than an absent one
- `rule.require.seam-claims-have-an-owner` — its `.prove the check discriminates`
  section; a check never seen to go red is an unproven check
