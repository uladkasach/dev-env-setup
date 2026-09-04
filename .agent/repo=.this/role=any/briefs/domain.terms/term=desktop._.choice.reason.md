# domain.term.choice.reason: desktop

## .etymology

a **desktop** is a desk's top — the surface a person sits at. the word carries the human in it,
which is precisely the fact the term must assert. every rejected candidate names some part of the
apparatus (a screen, a display server, a draw mode) and leaves the person out.

that is the whole choice: the repo does not need to know that pixels can be drawn. it needs to know
that **someone is there to answer a prompt.**

## .disputes

### dispute: `graphical` — raised 2026-07-30 — status: RESOLVED (keep `desktop`)

- raised.by  = mechanic, who had written both words into the same declaration in one round: the
               function was named `grove_env_probe_desktop` while its own `.what` line read *"does
               this shell sit in a GRAPHICAL session?"*
- claim      = `graphical` is the literal, checkable fact. the probe reads `WAYLAND_DISPLAY`,
               `DISPLAY`, and `XDG_SESSION_TYPE ∈ {wayland, x11, mir}` — every one of those is a
               statement about how a session draws, and none mentions a human. `desktop` therefore
               claims more than the test checks, which is the exact failure recorded against
               `has_screen` below
- counter    = the claim is right about the SIGNALS and wrong about the CONCEPT. we do not gate on
               "can pixels be drawn" — nobody cares. we gate on "may a prompt be offered", and a
               name should say what the caller needs, not what the file reads
               (`rule.require.ubiqlang`: name from the motive, not the mechanism).

               and `graphical` is not actually safer. a headless box with `Xvfb` has a graphical
               session and no human — so `graphical` would ALSO claim more than it checks, while it
               names the less useful half. it trades an honest approximation for a precise
               irrelevance.

               the residual risk the claim identifies is real, and is handled by scope instead of by
               name: the set of boxes is CLOSED at two, and on both of them screen and human agree.
               `term=desktop._.choice._.md` states the weld openly and names the box that would
               break it (`local@cicd`), with the instruction to split the term before that box is
               ever admitted.
- resolution = keep `desktop`; record `graphical` as a forbidden synonym. the probe's `.what` line
               was conformed the same round — a declaration may not use two words for its own
               concept, even when one of them sits in a comment. dispute closed.

## .evidence

### the precedent: `grove_env_has_screen`, deleted 2026-07-29

a predicate of this exact concept already existed and was removed. it failed for a reason worth a
record — **its name asserted a fact it could not check**:

```sh
grove_env_has_screen() { [[ "$GROVE_ENV_SERVER" == "local@unix" ]]; }
```

it read a derived string. it could not see a display. so on a `local@cicd` runner — local tier, no
display — it answered YES, and that very case was cited, in the same file, as the REASON the helper
existed.

it was also a synonym: `grove_env_has_human` had a byte-identical body. two names, one test.

so `desktop` inherits a hard constraint from its predecessor: **the term may name only what the
probe genuinely reads about the machine**, and the probe must read the machine — not a string
somebody else derived.

### the defect this term was hardened against, 2026-07-30

the probe body was:

```sh
[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}${XDG_SESSION_TYPE:-}" ]]
```

a non-empty test across all three concatenated. a grove publishes `XDG_SESSION_TYPE=tty`, so:

| | laptop (pop-os) | grove-1 (nitro) |
|---|---|---|
| `WAYLAND_DISPLAY` | set | （unset） |
| `DISPLAY` | set | （unset） |
| `XDG_SESSION_TYPE` | `wayland` | **`tty`** |
| the old probe | yes | **yes** ← wrong |
| the fixed probe | yes | no |

`tty` is the OPPOSITE of a desktop session, and it is non-empty, so a **headless box claimed a
screen.**

it never bit, because the ec2 probe answers first on that machine. an end-to-end check of `$server`
returns `cloud@aws.ec2` and passes clean — a **wrong probe hidden behind a right one**. it was found
only because the probes had just become individually askable (`term=probe`).

the fix reads the VALUE rather than the presence:

```sh
[[ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]] && return 0
case "${XDG_SESSION_TYPE:-}" in wayland|x11|mir) return 0 ;; esac
return 1
```

### the general lesson

both failures of this concept — the deleted predicate and the presence-test — are the same shape:
**a name that promises more than its body reads.** the first read a derived string and claimed to
see hardware; the second read an envvar's existence and claimed to see a session type.

so the term carries an obligation that stands for as long as the term does: when `desktop` changes,
read what the body checks before you trust what the name says.

## .invariants

- `desktop` may be asserted only from a fact read off the MACHINE, never from `$GROVE_ENV_SERVER`
  (that direction is derived FROM the probe; to reverse it is the `has_screen` defect)
- a session type must be matched by VALUE. presence is not a session type
- `desktop` and `local@unix` are two views of one fact, and exactly one of them — the probe — is
  the source. the other is its output
