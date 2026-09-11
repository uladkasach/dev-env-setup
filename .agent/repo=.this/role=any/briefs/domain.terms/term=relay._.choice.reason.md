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

## .disputes

### dispute: forward — raised 2026-09-07 — status: RESOLVED (keep `relay`; no new term earned)

- raised.by  = the round that authored `git.grove.auth.keys.set`
- claim      = `forward` was used ~30 times in that round's prose for a concept `relay` does
               not cover: **a secret value moved from a box that holds it into a box that does
               not**, over one ssh hop, with no human. that is not relay's concept, so the
               forbid was argued to be mis-scoped rather than violated.
- counter    = the two concepts differ on every axis, which is what makes the shared word an
               **overload** rather than a synonym — the worse of the two failures
               (`rule.forbid.domain-term-ambiguity`):

               | axis | `relay` | the disputed use |
               |---|---|---|
               | what moves | remote-chosen bytes, untrusted | a value this box already holds |
               | direction | a boundary → a human's terminal | this box → another box |
               | the hazard | an escape sequence reaches a terminal | the secret reaches argv or a pane |
               | the guard | a sink strips at capture | the value never materializes; it pipes |
               | who reads it | a human | no one — a rack stores it |

               ⇒ so the claim's premise held and its conclusion did not. a distinct concept
               earns a distinct word; it does not earn a **forbidden** one.

- resolution = **`relay` stands, and `forward` stays forbidden.** the disputed concept needs no
               coinage at all — keyrack already names it. the mechanism is
               `PERMANENT_VIA_REPLICA` and `os.secure` is a replica store, so the act is
               **"place a replica"**: `replica` is cited vocabulary from the dependency (as
               `KeyrackKeyHost` is in `term=entry`), and `place` is plain english that names
               no domain concept.

               ⚠️ and a coinage would have been premature regardless —
               `rule.require.enumerate-before-you-name` wants the instances listed first, and
               this round had exactly **one**. a word tested against one instance has been
               tested once.

⇒ **the drift is mine and it is recorded rather than quietly repaired.** I reached for
`forward` all round without a glob of the glossary, which is the precise failure
`rule.always.reuse-pavement-before-improvise` names — and the word was not merely unchosen, it
was on a forbidden list I never read. the prose conform is owed on next contact
(`rule.prefer.wickup-touched-prose`); no contract name carries the word, so none is blocked
meanwhile.

### 🛑 .the clause above was wrong on a POINT OF SCOPE, and that is why it took four rounds

*"no contract name carries the word"* is true and it is not the test.
`rule.forbid.domain-term-synonyms` binds **"above all the external interfaces we publish (api,
sdk, cli)"** — and a skill's **stdout is a cli surface**. `git.grove.auth.keys.set` printed
`would forward` · `forwarded` · `did not forward` from the hour it was written, so a contract
carried the word the whole time and the dispute recorded that none did.

⇒ the cost was measured the same day: **four contacts, and the count GREW at each.** the
deferral read as free because it was scoped to "prose", and the word kept reaching stdout
under that licence — the fourth round added two fresh printed lines before the glossary was
re-read.

✔ conformed 2026-09-07: every line the skill PRINTS says `place`, and `5.16.keys`' verify with
it. its comments still say `forward`, which the rule expressly allows, and the skill's header
says so inline so the next reader does not "fix" the stdout back.

⇒ **the durable half is about DEFERRAL, not about this word.** a conform deferred to
*"next contact"* has no owner and no trigger a reader can check
(`rule.require.exemptions-name-their-trigger` asks the same of an exemption). ⚠️ and the
narrower the deferral SOUNDS, the longer it survives: *"only the prose"* is what let a
published surface drift on under a resolved dispute.

## .evidence

- `src/ductwork.sh` — `__duct_strip_escapes`, and the measured table above, inline
- `.agent/repo=.this/role=any/skills/git.grove.operations.sh` — `_grove_relay_sunk`
- `term=sink._.choice._.md` — the complement; a relay feeds it, at capture
- `term=swallow._.choice._.md` — what a relay does when it drops a stream it owed
- `term=entry._.choice._.md` — the `replica` half the 2026-09-07 dispute resolves onto, and
  the precedent for a dependency's word cited rather than itemized
