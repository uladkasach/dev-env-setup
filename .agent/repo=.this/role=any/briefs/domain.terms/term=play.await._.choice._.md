# domain.term: play.await

term.chosen   = await (as the verb slot of a play name)
term.kind     = verb
term.synonyms.forbidden:
- wait (bare; says the play sleeps, never that it watches FOR a signal)
- watch (implies a live tail; this polls, because a grove may sleep mid-run)
- poll (names the mechanism, not the intent — and the mechanism may change)
- tail (unix's word for a stream follow; an await survives a dropped stream)
- monitor (reserved: a monitor runs forever; an await is bounded and ends)

## .what
the verb of a play that **waits for a run somebody else started, then reports its roll** — it
starts no run of its own, judges no claim, and mutates no state.

an `await` is the only verb in the family whose subject is a RUN rather than the machine. the
other four ask a question of the box; this one asks whether a run has reached its sign-off.

## .why it is its own verb, and not a `verify`
a `verify` asks a question the box can answer NOW. an `await` exists precisely because the
answer is not ready yet — so it is bounded, it polls, and its exit says whether the run STOPPED,
never whether the run was right. the roll it prints is what carries the verdict.

so an `await` that asserts pass/fail on the work it watched has taken a claim that belongs to
the run — the same defect as a `diagnose` that asserts a verdict.

## .the family it belongs to
a play's verb says what the play DOES to the machine:

| verb | reads? | may drive? | asserts a verdict? | its subject |
|------|--------|-----------|--------------------|-------------|
| `diagnose` | yes | no | **no** — reports every branch, judges none | the machine |
| `verify` | yes | **no** | yes — exits 0 or names each failed claim | the machine |
| `prove` | yes | **only via `grove.provision` or a suite** | yes — drives, then judges the result | the machine |
| `await` | yes | no | **no** — it reports a roll | **a RUN** |

🛑 there is no `repair` row: a play may never write machine state, and what writes is a
bundle (`rule.forbid.repair-plays`).

## .the two bounds an await owes
- **bounded in time** — an unbounded wait on a slept box hangs forever, and a grove is built to
  hibernate. so it carries a max and says so when the bound elapses
- **honest at the bound** — an elapsed bound is NOT a verdict on the run. the play that named
  this term once printed *"the box may have slept mid-run"* on a timeout it reached for an
  unrelated reason, which sent a reader to hunt a power bug that did not exist

## .refs
where the term is used:
- .agent/repo=.this/role=any/skills/git.grove.play.await.sh   # the verb in a SKILL slot

⚠️ the last ref is the verb's first use OUTSIDE a play file, and the slot flips: a play is
`<verb>.<subject>.play.sh` (verb first), a skill is `<subject>.<verb>` (verb last, per
`shell.syntax.verify`, `nvim.diagnose.runaway`). the WORD is the same choice and carries the
same two bounds; only its position moves. see the `.reason` for why that is a position rule
and not a second term.

## .reason
see the ref-level cluster beside this choice:
- `term=play.await._.choice.reason.md` — the broken-grep defect that settled it, why the
  subject-is-a-run split earns the verb, and the bound it must carry
