# domain.term: tool

term.chosen   = tool
term.kind     = noun
term.synonyms.forbidden:
- toolkit     (TAKEN, and a different concept: a SET of installed packages that carry no config
               of their own, held as `2.1.toolkit`. a toolkit is a thing you INSTALL; a tool in
               this sense is a thing you RUN — see `term=toolkit._.choice._.md`)
- linter      (names one instance. a compiler, a formatter, a syntax parser are all tools, and
               only some of them lint. legitimate in a COMMENT, describing one from another
               angle — never in a contract)
- checker     (every gate is also a checker, so the word cannot discriminate the two — which is
               the whole job of this term)
- helper      (blocklisted repo-wide for vagueness; it names a relation, never a subject)
- utility     (generic — says no word about what it does or who runs it. the same defect
               `toolkit` rejected `utils` for)
- command     (names the SHAPE of the artifact, not its role. a gate is a command too)

## .what

a **tool** is a check a human runs at their own work, whose verdict skips no later work.

it is a **role**, exactly as `gate` is — the same artifact can occupy either position. what
makes it a tool is that no work is gated on it: you run it, you read it, and you decide what to
do next yourself.

## 🛑 .it is the counterpart to `gate`, and the pair is the point

neither word is precise alone; the pair is (`rule.prefer.symmetric-term-pairs`). one axis
separates them, and it is **who invokes it** — never what it reads:

| | **gate** | **tool** |
|---|---|---|
| who runs it | the repo, at you | you, at your own work |
| when | on a commit, a push, a release | mid-edit, to check yourself |
| what a red means | stop; the change cannot land | look again; you are mid-thought |
| what turns on its verdict | later work is SKIPPED | no work is skipped |

⇒ so a tool is precisely a check that is **not in gate position** — which is why
`term=gate._.choice._.md` can say *"the same check is a gate in one position and a report in
another"* and stay true. this term names that other position, for the case where a human is the
caller.

## 🛑 .it was ALREADY in use, un-itemized — and this cluster is the reconciliation

`term=exhibit._.choice._.md` has carried `tool` in its peer set since 2026-08-11, defined by
**lifespan**:

| kind | what it is | lifespan |
|---|---|---|
| tool | reached for WHEN a fault appears | as long as the fault can recur |
| clamp | re-proves a claim on every box, forever | as long as the claim holds |
| exhibit | measured one argument, once | spent when the result lands |

⚠️ **that is this same term, seen from the other end.** *"reached for when a fault appears"*
names WHO invokes it — a human, at the moment they choose — which is exactly the axis above.
the two homes agree, and neither pointed at the other.

⇒ so the peer set is where `tool` earns its **lifespan**, and this cluster is where it earns
its **boundary against `gate`**. one concept, two facets:

| the question | answered by |
|---|---|
| who invokes it, and what turns on its verdict? | here — the `gate` opposition |
| how long is it kept? | `term=exhibit._.choice._.md`, the peer set |

⚠️ do NOT let the two drift. a fact with two holders and no link is the m.9 shape
(`gotcha.a-check-that-cries-wolf-gets-silenced`), and it went unlinked for three weeks.

## ⚠️ .the trap: the SUBJECT does not tell you which

a gate and a tool can read identical bytes. `tsc` reads files and reports errors exactly as a
lint gate does, and nobody calls it a gate — because a human runs it mid-edit, dozens of times,
and a red means *carry on*.

measured 2026-08-31: `shell.syntax.verify` was proposed for the `git.repo.test --what <x>`
family on the grounds that it reads files off a disk and drives no live surface. true, and about
the subject. the human overruled it — *"defo not a `--what shell`, its just a compiler or
linter. but a valid skill for the mechanic to check their work with"*.

## .refs

- .agent/repo=.this/role=any/skills/shell.syntax.verify.sh   # the tool that settled the term
- .agent/repo=.this/role=any/briefs/shell/rule.require.name-a-skill-by-who-invokes-it.md
- .agent/repo=.this/role=any/briefs/domain.terms/term=gate._.choice._.md   # the counterpart
- .agent/repo=.this/role=any/briefs/domain.terms/term=exhibit._.choice._.md   # the peer set,
                                                    # where the word was used before it was named

## .reason

see the ref-level cluster beside this choice:
- `term=tool._.choice.reason.md` — etymology, the `toolkit` collision, and the fulcrum that
  settled it
