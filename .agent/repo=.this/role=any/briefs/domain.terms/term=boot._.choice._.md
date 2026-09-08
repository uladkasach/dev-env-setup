# domain.term: boot (the verb of `git.grove.provision boot`)

term.chosen   = boot
term.kind     = verb
term.synonyms.forbidden:
- bootstrap   (the COMPLEMENT, not a synonym — a different act on a different subject. see below)
- provision   (names the DRIVER a boot calls per seat; a boot is the sequence around it)
- raise       (a bare synonym: it carries no sense `boot` lacks, so it buys only drift)
- init        (already forbidden under `grove.bootstrap`, and for the same reason)
- setup       (says none of who acts, on what, or when it ends)
- onboard     (the human's word for a person, not a box)

## .what

to drive a named grove from a bare box to acceptance-grade, **from this machine, over a duct**,
in one apply per seat — then run the gate as the last step with no command in between.

```sh
rhx git.grove.provision boot <name> --mode apply
```

it sequences four steps: reach (wake + trust), ground, camper, gate. the gap between the last
apply and the gate is the bar `rule.require.one-command-provision` exists to hold, so a boot
closes it by construction rather than by a human's discipline.

## 🛑 .`boot` and `bootstrap` are the COMPLEMENT pair — one root, two acts

they are near enough to cross, and the split is **who runs it, and on which box**:

| | `grove.bootstrap` | `boot` |
|---|---|---|
| runs ON | the bare box itself | THIS machine |
| run BY | a human, from `readme.md` | a mechanic, via a skill |
| subject | the machine you stand on | a NAMED grove, reached over a duct |
| its job | make a first start POSSIBLE | drive the whole sequence to a green gate |
| ends when | the repo is present | the gate exits 0 |

⇒ a bootstrap makes a start possible; a boot **is** the start, driven to its end. neither
substitutes for the other, and the pair is why the word needed a term of its own.

## ⚠️ .the verb is LOAD-BEAR, and its absence reads as a flag

`git.grove.provision` takes exactly two verbs — `boot` (writes) and `test` (reads) — so a call
with neither is refused. that refusal is correct and easy to misread: a `--from 2 --trust keep`
resume looks like a flag set, and the verb is what it lacks.

📜 measured 2026-09-06. the skill's OWN fix-text printed the resume command with the verb
omitted, so a human who copied it got `✋ git.grove.provision needs a verb`. the fix-text also
failed to list `boot` among the verbs it then named.

⇒ **a verb dropped from a fix-text is evidence the verb is not yet load-bear in its author's
mind either** (`rule.require.errors-name-the-fix`, and
`gotcha.a-check-that-cries-wolf-gets-silenced` m.4 — the verdict was right, the command it
handed back was wrong).

## ⚠️ .a boot is the ONLY sanctioned way to drive the four steps

the steps are written down in `rule.require.one-command-provision`, and they are written down as
a RECORD, never as a procedure to re-type. a hand-rolled sequence is the defect that rule names.

📜 measured 2026-09-06: a hand-rolled `git.grove.send --what 'rhx grove.provision --mode apply'`
exited **127** — `rhx` is absent from a ground seat's non-interactive PATH
(`gotcha.a-tool-found-by-path-answers-only-a-human`). `boot` carries the by-path carve-out that
`rule.forbid.the-driver-by-path` grants a SKILL and denies a human, so only the boot reaches it.

⇒ the word names the act you must reach for, and the hand-rolled twin has no path to succeed.

## .refs
- `.agent/repo=.this/role=any/skills/git.grove.provision.boot.sh`  # the artifact
- `.agent/repo=.this/role=any/skills/git.grove.provision.sh`       # the dispatcher that owns both verbs
- `rule.require.one-command-provision`                              # the bar a boot holds
- `rule.forbid.the-driver-by-path`                                  # carve-out 1, which a boot owns
- `term=grove.bootstrap._.choice._.md`                              # the complement

## .reason
see the ref-level cluster beside this choice:
- `term=boot._.choice.reason.md` — etymology, the bootstrap split, and the two measurements
