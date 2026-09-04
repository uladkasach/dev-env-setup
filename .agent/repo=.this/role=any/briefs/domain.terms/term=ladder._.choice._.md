# domain.term: ladder

term.chosen   = ladder
term.kind     = noun
term.synonyms.forbidden:
- pipeline    (a pipeline's stages run independently; a ladder's do not)
- chain       (names order and no halt — a chain that breaks mid-way still ran its tail)
- sequence    (names order alone; a ladder's whole point is the DEPENDENCE)
- flow        (names neither order NOR dependence)
- suite       (a suite runs every member and tallies; a ladder halts at the first that fails)
- checklist   (a checklist's items are independent; a rung's value is its position)

## .what
an **ordered set of rungs where a failure at one makes every rung above it
meaningless**. it climbs from the bottom, halts at the first rung that does not hold,
and names that rung's fix.

```
1. registry → 2. reach → 3. duct → 4. tree → 5. creds
                            ↑ rung 3 fails ⇒ 4–5 are unreachable, not merely unrun
```

## 🛑 .the three properties — ALL of them, or it is not a ladder

| property | what it means | what it rules out |
|---|---|---|
| **ordered** | the members have a fixed climb order | a set, a bag, a menu |
| **load-bear** | member N+1 is *meaningless* if N did not hold | a suite, a checklist |
| **halts** | the climb stops at the first that does not hold | a tally, a report of N reds |

⚠️ **read/write is NOT on that list**, and its absence is the whole point. the human
settled the axis on 2026-08-30: a ladder's members are **rungs whatever they do**, so a
ladder that WRITES is a ladder. what makes it one is the dependence between its members,
never the effect of any one of them (`term=rung._.choice._.md`, `.the axis`).

⇒ the test is one question: **does a failure here make the members above it meaningless?**
yes ⇒ a ladder, and its members are rungs. no ⇒ a generic ordered list, and its members
are steps.

## .the three ladders this repo declares

| ladder | numbers | subject |
|---|---|---|
| `git.grove.ready.verify` | 1..5 | the box — read-only |
| `git.grove.provision test` | 0..4 | the box, plus a tree on it |
| `git.grove.provision` boot | 1..4 | reach → ground → camper → gate |

🛑 **three ladders means every number is ambiguous on its own.** `2` names a different
question in each, so a citation that does not name its ladder is unreadable — and the
cost is measured: one sentence cited *"rungs 0-3"*, fusing the gate's `0` into the
verify's band, and told a reader that three checks which run ON the box could fail on
their laptop.

⇒ **name the ladder, then the number.** *"the gate's rung 0"*, *"the verify's rung 2"*.

⚠️ and the qualifier is now the ONLY discriminator. before the axis settled, the two
NOUNS told the two number sets apart — `step N` meant the gate, `rung N` meant the verify.
the axis retired that split, so a passage that leaned on it kept its claim and lost its
support (`rule.require.one-command-provision`, the 📜 under *"the ONE interjection"*).

## ⚠️ .a WIDER use, accepted 2026-08-10 rather than left to drift

the word was coined for a ladder of QUESTIONS. it was then reused for a **dependency
chain** — git → its credential helper → `rhx` → `node` — where each layer's absence made
the layers above it unaskable, and each repair uncovered the next.

that is the same three properties exactly, over a different subject: a **dependency**
rather than a **question**. so the word is wider than its coinage and has not drifted to
a synonym. it is recorded here so a later contract that must tell the two apart has a
note saying the ambiguity was seen and accepted.

## .refs
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh`      # rungs 1–5, halts, names the fix
- `.agent/repo=.this/role=any/skills/git.grove.provision.test.sh`    # rungs 0–4
- `.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh`    # rungs 1–4
- `.agent/repo=.this/role=any/briefs/shell/gotcha.a-tool-found-by-path-answers-only-a-human.md`  # the wider use

## .reason
see the ref-level cluster beside this choice:
- `term=ladder._.choice.reason.md` — the etymology, the settled axis it carries, and why
  the halt is the design rather than an economy
