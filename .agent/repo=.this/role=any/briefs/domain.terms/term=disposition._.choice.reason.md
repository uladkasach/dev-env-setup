# domain.term.choice.reason: disposition

## .etymology

from the legal and archival sense: *the disposition of a case* is the recorded outcome a
human entered, which binds later readers. it is a matter of RECORD, not of re-argument.

that is exactly the load this word carries here. a **verdict** is spoken by whoever decided;
a **disposition** is the entry that survives them, and the thing a later reader is held to.

`verdict` was the natural reach and it lost, because this repo had already spent the word on
a different axis (`term=verdict._.choice._.md`):

```
report   → a fact about the CARRIAGE
verdict  → a fact about the SUBJECT
```

that pair splits by **who carried it**. a disposition splits by **who judged it, and when** —
an orthogonal axis. to spell both `verdict` would overload one word across two axes, which is
the defect `term=reader._.choice._.md` names when it refuses `checker` for the same reason.

## .disputes

### dispute: verdict — raised 2026-09-02 — status: RESOLVED (keep `disposition`)
- raised.by  = mechanic, while authoring `prove.rack-consumers-are-dispositioned`
- claim      = the census rows ARE verdicts — each says what a call site does with its value.
               a second word for a judgment is synonym sprawl.
- counter    = a verdict is what a COMMAND concluded at RUN time, and the whole reason the
               word exists is to be told apart from a `report`. the census holds no such
               judgment: no command ever decided whether `5.4.gh` persists its token — a
               HUMAN read it and wrote it down. to call that a verdict would let a reader
               believe the check re-derives it on every run, which is precisely the false
               confidence the census was built to avoid.
- resolution = keep `disposition`; record `verdict` as a forbidden synonym, with the
               judge/moment split spelled in the say file. dispute closed.

### dispute: exemption — raised 2026-09-02 — status: RESOLVED (keep both, they are distinct)
- raised.by  = mechanic
- claim      = `term=exemption` already names "a row a rule agreed not to bite", which is
               what the `PERSISTS` row looks like.
- counter    = opposite direction. an exemption REMOVES a site from a rule's reach; a
               disposition keeps it fully in reach and merely records what was found there.
               the `PERSISTS` row is measured on every run, printed on every run, and would
               redden if its count moved — an exempt row would do none of the three.
- resolution = both stand. `exemption` is a forbidden synonym of `disposition`, and the
               reverse is equally forbidden. dispute closed.

## .evidence

### the measurement that made the word necessary — 2026-09-02

`inventory.security-checks.md` carried a row claiming *"a secret at rest on a box"* is
guarded. the claim was FALSE — `5.4.gh` pipes a pat into `gh auth login --with-token`, which
writes it to `~/.config/gh/hosts.yml` in cleartext.

that instance was found by a human reading prose. the CLASS had never been swept.

the obvious reader was tried and refused on principle: a grep for the tools that persist
(`gh auth login`, `npm config set`, `docker login`, `.netrc`) is a hand-written tool list,
which `rule.require.one-command-provision` grades a blocker — *"it cannot report the member
nobody added"*. the reader keys on the secret's ONE SOURCE instead, so it cannot miss a
consumer.

but the source walk finds CALL SITES; it cannot follow the value. dataflow across a shell
function is not a thing a grep reads, and `term=reader` carries the dated proof of what
happens when one pretends otherwise — several hundred correct lines flagged, deleted the
same hour.

⇒ so the reader stops at the honest question, and the census carries the rest:

| class | n | |
|---|---|---|
| `NAME` | 8 | the key is `AWS_PROFILE` — a selector, not a secret |
| `MEMORY` | 3 | a real secret, and it never reaches disk |
| `PERSISTS` | 1 | `5.4.gh` — the instance the human had already found |

**the prose instance was the class's only member.** that is a result either way: a second
would have been a finding, and its absence is the first evidence the exception list is
complete.

### the three drift arms, seen RED — 2026-09-02

a clamp never seen to fail is a guess (`rule.require.clamp-edge-cases`). the census was
perturbed three ways in one run and each fired its own row, while the other nine stayed ✔:

| perturbation | reported |
|---|---|
| dropped a row | ✋ UNDISPOSITIONED |
| set a count 1 → 9 | ✋ COUNT MOVED |
| added a row for a site with no call | ✋ STALE ROW |

### ⚠️ the counter has a second place to be wrong

this repo documents its own call shapes in prose beside the calls.
`src/git-credential-keyrack.sh` names `rhx keyrack get` in a comment and inside an `echo`
fix-text, one screen from its one live call. a naive counter reads 3 where the answer is 1.

that is m.8 — a reader that re-authors its subject gains a second place to be wrong, one no
pattern review surfaces. the counter strips comments and `echo`/`printf` lines, and proves
that on four fixtures before it is aimed at a real file.

## .note — the word is not bound to secrets

no part of the term is about credentials. a disposition fits any property that is real,
matters, and has no expressible reader. the rack census is its first instance, never its
definition.
