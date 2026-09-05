# domain.term: rung

term.chosen   = rung
term.kind     = noun
term.synonyms.forbidden:
- step         (forbidden INSIDE A LADDER only — `step` is the GENERIC word for an ordered
                member, and stays legal everywhere a ladder is not in play. see `.the axis`)
- stage        (implies a pipeline whose members run independently; a ladder's do not)
- check        (a check is standalone; a rung's whole value is its position in a ladder)
- phase        (taken — a bundle's four phases, per `term=bundle`)
- gate         (a gate opens or refuses; a rung also NAMES ITS FIX when it does not hold)

## .what
one **ordered member of a ladder, where a failure makes every member above it
meaningless**. a rung answers or acts, halts, and names the fix.

```
1. registry → 2. reach → 3. duct → 4. tree → 5. creds
                            ↑ rung 3 fails ⇒ 4–5 are unreachable, not merely unrun
```

## 🛑 .the axis is LADDER vs GENERIC — never read vs write

**settled by the human, 2026-08-30.** a ladder's members are **rungs**, whatever they do. a
rung that WRITES is still a rung; what makes it one is its position, not its effect.

| | `rung` | `step` |
|---|---|---|
| what it is | an ordered member of a **ladder** | the **generic** word for one ordered move |
| the ladder | ordered · load-bear · halts at the first that does not hold · names its fix | — |
| examples | `git.grove.ready.verify` 1-5 · `git.grove.provision test` 0-4 · `git.grove.provision` 1-4 | a recipe, a howto's numbered list, a README walkthrough |

📜 **an earlier draft split them on READ vs WRITE** — `rung` for a ladder that asks, `step`
for one that acts — and that axis was overruled. it does not survive its own test: a member's
effect is a property of that member, where a member's DEPENDENCE on the one below it is a
property of the whole. only the second is what the ladder metaphor carries, so only the
second can be the axis.

### ⚠️ .TWO of the three anchors still spell their members `step` — measured 2026-08-30

the axis settled the word; not one artifact was renamed. the table above lists three ladders,
and only the first conforms:

| ladder | what its own artifact prints | conforms? |
|---|---|---|
| `git.grove.ready.verify` 1-5 | `rung` | ✔ |
| `git.grove.provision test` 0-4 | `# step 0 — box` … `# step 4 — suite`, 12 sites | ✋ |
| `git.grove.provision boot` 1-4 | `echo "the steps:"`, `--from  first step to run (1-4)` | ✋ |

🛑 **the third row is the expensive one and was recorded nowhere until now.** those strings are
`--help` output and a flag's own description — a **published cli contract**, which is precisely
where `rule.forbid.domain-term-synonyms` calls a forbidden synonym a blocker rather than a
nitpick.

⚠️ and the repair is **not** a bare rename. today the WORD tells the two number sets apart:
inside `git.grove.provision.test.sh`, `step N` means this command and `rung N` means the verify
it climbs, in all 26 sites. rename both to `rung` and that discriminator is gone — which is the
exact fusion `m.10` cost an hour to repair (`rule.require.one-command-provision`, the 📜 under
*"the ONE interjection"*).

⇒ so the conformance repair must land **with** the qualifier, never before it: every citation
names its ladder first (*"the gate's rung 0"*, *"the verify's rung 2"*), and only then may the
noun be shared. flagged, not driven — a 3-artifact rename plus ~40 citations is its own ask
(`rule.forbid.inflate-an-additive-ask`).

⇒ **`step` is not banned; it is the fallback.** use it wherever a ladder is not in play.
inside a ladder it is a forbidden synonym, because it drops the dependence that made the
ladder worth a name of its own.

### 📜 .the anchor once held a member this definition REJECTED — resolved 2026-08-30

`git.grove.ready.verify` carried two further members, `6 tree` and `7 suite`. rung 7 ran
`git.repo.test --what integration --mode apply` against a live testdb — a WRITE, and the
identical command `git.grove.provision test` step 4 issues. so by the table above it was a
**step**, at a rung's number, inside a ladder whose header promised read-only.

⇒ **the word did not drift; the LADDER did.** the repair was a DELETE of both, not a widened
definition — the human settled it, and named a sharper reason than the drift: 6-7 were
**synonyms** of `git.grove.provision test` steps 1, 2, and 4. one set, two readers, free to
disagree (`gotcha.a-check-that-cries-wolf-gets-silenced` m.9).

⚠️ **the durable lesson is about ANCHORS, not about this ladder.** a term anchored in a
shipped artifact inherits that artifact's drift: the anchor is what makes the term checkable
rather than asserted, and it is also what lets a later commit falsify the definition with no
signal to the glossary. the full account is in `.reason`.

🛑 **the two are NOT interchangeable, and a mix-up has a measured cost.** on 2026-08-30 one
sentence spoke of *"rungs 0-3"* — smoketest step numbers with ready.verify's subject split —
and told a reader that steps 1-3 (`tree`, `deps`, `fixture`) could fail on their laptop.
all three run ON the box. the full account is the 2026-08-30 dispute in `.reason`.

⇒ when you cite a number, name its ladder. `step 2` and `rung 2` are different questions.

## ⚠️ .why a rung HALTS rather than reports

a ladder that runs every rung and tallies at the end reports a wall of red whose rows are
almost all consequences of row one. that is noise a human must then re-derive an order for.

so the halt is the feature: **the first rung that does not hold is the only actionable
row**, and it is the last line printed.

## ⚠️ .a rung must read the answer, never the send

a rung that reads a remote box over the default duct judges the SEND's exit code, which is
0 whenever the text landed (`gotcha.the-duct-returns-the-send-not-the-answer`). three
rungs printed ✔ on a bare box before this was measured.

⇒ every rung passes `--bare`.

## .the shape a rung owes
| owes | why |
|---|---|
| one question | a rung that asks two cannot name which half failed |
| a verdict from the SUBJECT | not from the transport that carried the question |
| its own fix, on halt | `rule.require.errors-name-the-fix` |

## ⚠️ .a second, WIDER use — cited 2026-08-10, and deliberately not a new word

the word was coined for a VERIFY ladder. on 2026-08-10 it was reused for a **dependency
chain**: git → its credential helper → `rhx` → `node`, where each layer's absence made the
layers above it unaskable, and each repair uncovered the next.

that is the same sense exactly — ordered, load-bear, halt at the first that does not hold —
with a different subject: a **dependency** rather than a **question**. so the word is wider
than its coinage, never drifted to a synonym, and it is recorded here rather than left to
widen unremarked (`rule.forbid.domain-term-synonyms` binds CONTRACTS; that use is prose).

⇒ if a contract ever needs to tell the two apart, this is the note that says the ambiguity
was seen and accepted.

## .refs
- `term=ladder._.choice._.md`   # the WHOLE this term is a member of; carries the same settled axis
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh`   # `halt`, rungs 1–5
- `.agent/repo=.this/role=any/briefs/grove/reach/howto.grove-ready-test.md`
- `.agent/repo=.this/role=any/briefs/shell/gotcha.a-tool-found-by-path-answers-only-a-human.md`  # the wider use, above

## .reason
see the ref-level cluster beside this choice:
- `term=rung._.choice.reason.md` — the etymology, the `step` dispute, and why the halt
  is the design rather than an economy
