# domain.term.choice.reason: sink

## .etymology

a plumber's word. a sink is where a stream GOES, and the point is that there is one of
them — you do not put a second sink halfway along the pipe and hope both are plumbed.
that singular sense is the whole property this term exists to carry (m.9).

chosen over:

| rejected | why |
|---|---|
| `filter` | a filter says what it REMOVES, and this one is defined by what it must PASS. a filter that ate `├` and 🐢 for a release was still a filter; it was not a sink that worked |
| `sanitizer` / `scrubber` / `cleaner` | each implies the bytes are *dirty* and get *washed*. the bytes are fine; it is the TERMINAL that obeys them. the hazard is the reader, never the value |
| `strip` as a noun | `__duct_strip_escapes` is the VERB it performs. to name the place and the act with one word loses the "there is exactly one place" claim, which is the term's entire job |

## .the property the word carries, and a `grep` does not

measured 2026-09-01, `git.grove.auth.github.set`. it captured a grove's answer with
`2>&1` and read it through:

```sh
echo "$RHX_RUNS" | grep -m3 -E 'Error|Cannot find|BadRequest|✋'
```

that is not a sink and it looks like one. a grep constrains **which lines print** and
says none of what **bytes** they hold — an attacker writes the word `Error` on the same
line as the payload. a sink is keyed on the byte, never on the line.

## .disputes

### dispute: filter — raised 2026-09-01 — status: RESOLVED (keep `sink`)
- raised.by = the author of this cluster
- claim = `filter` is the ordinary unix word for a program that reads a stream and
  writes a transformed one, and `__duct_strip_escapes` IS one by that definition
- counter = true of the FUNCTION and false of the ROLE. this repo has many filters; it
  has one sink. the term is not for "a program in a pipe", it is for "the single point
  at which a boundary's bytes are made inert" — and the whole enforcement (`2.7.aliases`
  counts the joins, and refuses a second `ssh` seam) rests on the singular sense. name
  it `filter` and a second one reads as ordinary
- resolution = keep `sink`; `filter` is a forbidden synonym in a contract, and remains
  fine in prose about the function's shape

## .evidence — two measurements, each a sink fed HALF its input

**r7 B1, 2026-08-31** — the sink guarded STDOUT alone. `ssh` relays the remote command's
stderr byte-for-byte onto local fd 2 (`SSH_MSG_CHANNEL_EXTENDED_DATA`), and a pipe
carries neither. four sites. the sink was in perfect health and was fed one stream of
two — which is why property 3 is stated in the term rather than left to a reader.

**r8 B2, 2026-09-01** — `git.grove.auth.github.set` had no sink at all, while three
neighbours in the same directory each carried a 15-line block to load one. one fact,
four holders, and the holder that never loaded it was invisible to every reader of the
other three.

⇒ both are property 1 and property 3 stated as defects. the term is written so that a
future author has to consider all three, rather than re-derive them.

## ⚠️ .property 3 QUALIFIED — 2026-09-01, and it nearly condemned correct code

property 3 read *"stdout and stderr both"* flatly. read that way it condemns
`git.grove.push`'s rsync call, which sinks stderr alone — and that call is CORRECT.

measured, rsync 3.2.7, against a tree that held a filename with a real OSC 52:

| flags               | stdout                                            |
|---------------------|---------------------------------------------------|
| `-az` (what ships)  | 0 bytes                                           |
| `-az --no-links`    | 45 bytes — a skip notice, and it NAMES the file   |
| `-az -v`            | 189 bytes — one line per file                     |

⇒ **which streams carry remote text is a property of the ARGUMENT LIST, never of the
tool.** row 1 is why one stream suffices at that call; row 2 is the pull's own shape, and
it names a grove-chosen path on an unsunk stdout.

### ⚠️ the second half, which neither note in the tree had

row 2 sounds like an open hole and is not: **rsync escapes a non-printable byte in a
filename itself.** the OSC 52 symlink came out as the literal text `\#033]52;c;…`, on the
`-v` list and on the skip notice alike. no ESC byte reached the terminal.

so the pull is safe — by RSYNC'S escape, never by an absence of names. that distinction is
load-bear: an absence-of-names story makes `--no-links` look free to add anywhere.
`-8` / `--8-bit-output` is exactly the opt-out of that escape, and must never reach an
rsync whose output a grove chooses.

⚠️ **the durable shape**: `git.grove.push` stated this as settled fact while
`git.grove.pull` recorded the SAME property as explicitly unmeasured. one fact, two
holders, opposite epistemic status — and the CONFIDENT copy is the one a later author
cites (`gotcha.my-own-note-became-my-evidence`). the claim survived the measurement; its
stated REASON did not.

## .see also

- `term=swallow._.choice._.md` — a stream DISCARDED, which is the opposite failure
- `term=boundary._.choice._.md` — a sink sits at one
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9, the one-fact-many-holders shape
