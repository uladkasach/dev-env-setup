# domain.term.choice.reason: relay

## .etymology

a relay CARRIES a signal onward without authorship of it. that is exactly the role: the
bytes belong to the grove, and the relay's whole job is to move them to a terminal that
will obey them. the word names the danger — a relay is a conduit, so whatever it carries
arrives.

chosen over:

- **forward** — too weak. it says the bytes moved and says none of the obligation that a
  move creates. every defect this term exists to name is an obligation a forwarder did
  not know it had.
- **pipe** — a pipe is a shell mechanism. a relay may be a pipe, a `printf`, a heredoc, or
  an ssh channel. to name the concept after one implementation is `term=sink`'s own
  mistake in reverse.
- **echo** / **print** — worse than imprecise, they are the WRONG implementation. `echo`
  is a builtin whose escape expansion differs by shell (see below), so to name the
  concept after it teaches the defect.
- **surface** — used elsewhere in this repo for what a CHECK does with a defect it found.
  one word, two concepts is the overload `rule.forbid.domain-term-synonyms` forbids.

## .the split this term exists to hold — SAFETY vs SIGNAL

measured 2026-09-01, and it is why a relay is worth its own word rather than a sentence
inside `term=sink`.

`__duct_strip_escapes`' header claimed *"its absence fails CLOSED: `set -o pipefail` turns
an absent stage into a non-zero exit for every caller"*. the function set no such option,
so that was a claim about the CALLER's shell state. with `iconv` hidden behind a crafted
PATH:

| tree     | caller's opts | rc      | bytes out | raw ESC |
|----------|---------------|---------|-----------|---------|
| healthy  | pipefail      | 0       | 16        | none    |
| healthy  | bare          | 0       | 16        | none    |
| crippled | pipefail      | 127     | 0         | none    |
| crippled | bare          | **0**   | 0         | none    |

row 4 is the falsification. and the SHAPE of the defect is the lesson:

> **the SAFETY half was true the whole time, and the SIGNAL half was false.**

every crippled row emitted ZERO bytes — an absent stage DROPS the stream rather than
relays it unstripped. so no unguarded byte ever reached a terminal. what was lost was
only the caller's knowledge that the strip had not run.

⚠️ that is why it survived. **a claim whose dangerous half is true reads as verified
whenever anybody spot-checks it**, and the half that is false is the half no spot-check
looks at (`gotcha.a-check-that-cries-wolf-gets-silenced`).

⇒ the repair was at cause: the sink now carries its own `set -o pipefail` in a subshell,
so the exit code is the FUNCTION's guarantee at every caller. row 4 reads 127.

## .why `echo` is FORBIDDEN, and not merely discouraged

measured on the same day, one layer out. `__duct_strip_escapes` is a BYTE filter, so it
cannot see an escape spelled as the four printable characters `\`, `0`, `3`, `3` — and it
correctly passes them. zsh's builtin `echo` then EXPANDS them:

```
zsh -c 'held="$1"; echo "held=$held"' _ 'bash\033]52;c;cHdubmVk\007'
   → 1b 5d 35 32 3b 63 3b …          # a REAL OSC 52, written by the relay itself
bash -c 'held="$1"; printf "held=%s\n" "$held"' _ '…'
   → 5c 30 33 33 5d 35 32 …          # inert text, in both shells
```

so a sink and a `printf` relay are BOTH required, and a fix for either alone leaves the
other open. `duct.send`'s BUSY block relayed a `#{pane_current_command}` three times with
`echo`; `__duct_pane_command`'s local branch had no capture-time strip at all.

## .why the relay is NAMED, and not two inline lines

`_grove_err_sunk` and `_grove_ssh_sunk` each held the same two lines:

```sh
[[ -s "$err" ]] && __duct_strip_escapes < "$err" >&2
```

both discarded the sink's exit code, so the sink's promise was false at the only two
callers that mattered. one guarantee, two hand-written consumers, and each drifted the
same way (m.9). `_grove_relay_sunk` is that relay, declared once.

⚠️ and its status is deliberately NOT merged into its caller's return: `_grove_err_sunk`
promises the COMMAND's exit code, and to raise it because the relay broke would report a
push that worked as a push that failed. so the relay SHOUTS and the caller writes `|| :`
on purpose, rather than by an omission a later reader would take for an oversight.

## .evidence

- `src/ductwork.sh` — `__duct_strip_escapes`, and the measured table above, inline
- `.agent/repo=.this/role=any/skills/git.grove.operations.sh` — `_grove_relay_sunk`
- `term=sink._.choice._.md` — the complement; a relay feeds it, at capture
- `term=swallow._.choice._.md` — what a relay does when it drops a stream it owed
