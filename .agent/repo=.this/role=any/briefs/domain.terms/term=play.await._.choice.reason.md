# domain.term.choice.reason: play.await

## .etymology

**await** is transitive where **wait** is not. you *wait*; you *await something*. that grammar is
the whole distinction the term needs: this play does not idle, it waits FOR a named signal — the
driver's sign-off line — and it is done the moment that signal lands.

`wait.grove.provision` would read as a play that sleeps. `await.grove.provision` reads as a play
that watches for the upgrade to finish, which is what it does.

## .the argument that produced it

the verb was in use in a filename long before it was itemized, and it was promoted into the
family table of the playbook readme on 2026-07-31 without a cluster beside it. that is
the exact gap the round before had just written down:

> the trigger to watch is not "a new concept appeared" — it is **a new word reached a filename**.

so this cluster exists because the previous round's lesson was applied to the current round's
work, at ONE file rather than at four (`prove` reached four before anyone judged it).

## .why the family needed a fifth verb

the extant verbs all take **the machine** as their subject: they read it and judge it. `await`
takes **a run** as its subject. that is a different kind of question, and it is why none of them
fit:

| candidate | why it fails |
|---|---|
| `verify` | a verify asks what the box can answer NOW. an await exists because the answer is not ready |
| `diagnose` | a diagnose reports branches of a state; an await reports the ROLL of a run |
| `prove` | a prove DRIVES the run. an await starts none — somebody else's run is the point |

📜 a fourth candidate, `repair`, was weighed here and rejected because an await mutates no state
at all. that verb has since been **deleted outright** (2026-08-10): a play may never write, so
there was no `repair` for an await to be contrasted against. the rejection stands; its subject
does not (`rule.forbid.repair-plays`).

the split is clean and it is not a shade of meaning: an `await` is the only play that would still
have work to do on a machine that is already exactly as it should be.

## .the evidence — the defect that settled the term's contract

the play now called `await.grove.provision` polled for the literal string `install_env done` until
2026-07-31. that string was printed by `install_env._.sh`, DELETED on 2026-07-30 — so the grep
could never match again. every run burned its full 2400s bound and then reported:

```
✋ still not done after 2400s — the box may have slept mid-run
```

two defects, and the second is the one that shapes this term:

1. **a stale string in a `grep` is a broken play that still looks like it works.** the same string
   in prose would be a stale pointer, noticed on the next read. in a `grep` it is silent.
2. **the bound was reported as a VERDICT.** the play asserted a cause — the box slept — that it
   had no way to observe. a run that had finished cleanly in two minutes was reported as a
   hibernation fault, and it sent the reader to hunt a power bug that did not exist.

so the term carries an explicit contract: an await reports whether the run STOPPED, never whether
it was right, and an elapsed bound is *the bound*, not a diagnosis.

a third lesson landed with the repair: the driver signs off two ways —

```
🌲 grove.provision done — <server report>            (exit 0)
✋ grove.provision finished with failures — …        (exit 1)
```

— and a wait that matched only the happy one would sit the full bound on a run that ENDED in
failure minutes earlier. an await matches EVERY terminal line, because its question is "has this
stopped?" and a failure is a stop.

## .the verb crossed into a SKILL slot — 2026-07-31

`git.grove.play.await` is the verb's first use outside a play file, and it flips position:

| artifact | shape | example |
|---|---|---|
| play | `<verb>.<subject>.play.sh` — verb FIRST | `await.grove.provision.play.sh` |
| skill | `<subject>.<verb>` — verb LAST | `shell.syntax.verify`, `nvim.diagnose.runaway` |

that is a **position rule of the two artifact kinds**, not a second term. the evidence is that
the flip is already settled independently: every skill in this repo puts its verb last
(`git.grove.wake`, `duct.send`, `machine.diagnose.lag`), and every play puts it first. a word
that moves slot but keeps its sense has one cluster, not two — the same way `verify` is one
word across `play.verify` and `shell.syntax.verify`.

what does NOT move is the contract. `git.grove.play.await` carries both bounds:

- **bounded in time** — `--within`, default 1800s
- **honest at the bound** — its timeout branch says *"this is a bound, not a verdict"* and
  exits 2, distinct from the 1 it uses when tmux could not be asked at all

the second is the direct descendant of the defect below: the elapsed bound asserts no cause.

⚠️ it also inherits the lesson one layer deeper. the play below broke because it polled for a
**rendered string**; this skill polls for a **state** — `#{pane_current_command}` against
ductwork's shell set — so there is no literal to go stale. an empty answer from tmux is read as
*unknown*, never as *idle*, because "the pane runs no command" and "tmux could not be reached"
are opposite facts that a naive check would collapse into one ✔.

## .disputes

no dispute is open.

## .see also
- `term=play.verify._.choice._.md` — the read-and-judge sibling, and the family's first split
- `term=play.prove._.choice._.md` — the drive-then-judge sibling, and the second split
- `term=play._.choice._.md` — the family, and the verb-leads-the-name rule
- `term=grove.wake._.choice._.md` — why a bound matters: a grove is built to hibernate mid-run
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the false-✋ family this play's timeout joined
