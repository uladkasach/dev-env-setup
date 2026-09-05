# domain.term: play.verify

term.chosen   = verify (as the verb slot of a play name)
term.kind     = verb
term.synonyms.forbidden:
- check (says a claim was looked at, not that it was judged)
- test (jest's word here; a play is not a test suite)
- validate
- confirm
- ensure (names an act that MAKES a claim true — and an act that makes a machine claim true
          is a BUNDLE, never a play; `rule.forbid.repair-plays`)
- audit (reserved: an audit reports an inventory, it judges no claim)

## .what
the verb of a play that **judges a claim about a machine and asserts a verdict** — and writes
no file, runs no upgrade, changes no state.

read-only is not a convention layered onto the word; it is what the word means. a play that
writes has already stopped to verify the state it found.

## .the family it belongs to — THREE verbs, and every one only READS the machine
a play's verb says what the play does:

| verb | reads? | may drive? | asserts a verdict? |
|------|--------|-----------|--------------------|
| `diagnose` | yes | no | **no** — reports every branch, judges none |
| `verify` | yes | **no** | **yes** — exits 0 or names each failed claim |
| `prove` | yes | **only via `grove.provision` or a suite** | yes — it drives, then judges what came out |

🛑 there is no `repair` row: a play may never write machine state, and what writes is a
bundle (`rule.forbid.repair-plays`).

the pair easiest to confuse is `diagnose` / `verify`, and the split is the VERDICT, not the
writes: a diagnose that asserts a verdict hides the branch a reader needed to see, and a verify
that asserts none is a log.

the pair easiest to BLUR is `verify` / `prove`, and that split IS the write. a claim about what
a run does — is this idempotent? does the tree settle? — cannot be read off a box, so it earns
its own verb rather than a loosened `verify` (`term=play.prove._.choice._.md`).

## .reason
see the ref-level cluster beside this choice:
- `term=play.verify._.choice.reason.md` — the defect that settled it, the family contrast,
  and the trigger that would earn `play.diagnose` its own cluster
