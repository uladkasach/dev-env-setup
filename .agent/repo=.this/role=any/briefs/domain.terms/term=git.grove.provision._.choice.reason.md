# domain.term.choice.reason: provision

## .etymology

`provision` = to supply what is needed beforehand. it names the ACT of readiness
rather than the state, which is the whole point: this repo already had four words
for the state a box ends in (`ready`, `converged`, `parity`, `acceptance-grade`)
and none for the act that takes it there.

⇒ and the repo's prose carried it before it was a term. two always-booted rules
hold it in their FILENAMES:

```
rule.require.one-command-provision
rule.forbid.deferred-provision-defects
```

so the word governed the concept for weeks while no operation bore it. this
cluster is that word promoted, never a coinage (`rule.require.ubiqlang` — adopt
the word in use where no better one exists).

## .why the sequence earned a verb — measured 2026-08-26

`howto.provision-a-grove.md` carried the act as **seven prose commands for a
human to type in order**. that is a skill written as prose, and it failed twice
in ten minutes on one box:

| what happened | the prose could not |
|---|---|
| a `git.grove.push` run with no prior `wake` → `connect to host localhost port 36902: Connection refused` | make a step unskippable |
| six commands piped `\| tail`, so each discarded its exit code — an `exit 0` printed over `💥 failed with an error` | check a code the human did not read |

⇒ **an ordered list a human types is a list a human can reorder.** the ORDER here
is load-bear and invisible: camper-first draws a ✋ from every box-wide bundle,
since that seat holds no sudo by design (`term=seat`), and each ✋ names a defect
that is not one.

`rule.require.wrap-cli-in-skills` says it directly. this measurement made it
concrete.

## .the rejected synonyms, and why each lost

| word | why it lost |
|---|---|
| `setup` | names the STATE reached, and says no word about the act. the four state-words already existed; the gap was the verb |
| `bootstrap` | **taken.** `grove.bootstrap` is the pre-repo first contact — the one artifact that runs BEFORE a checkout exists. an overload would erase the distinction the exemption rests on |
| `configure` | **taken.** it is one of a bundle's four phases. a word that means "phase 3 of a leaf" cannot also mean "the whole box, end to end" |
| `upgrade` | **taken.** `grove.provision` is the one entrypoint, and this DRIVES it. a sequencer named for what it calls hides which of the two writes |
| `deploy` | moves an artifact TO a box. this converges the box ITSELF — the opposite direction |
| `install` | superseded repo-wide on 2026-07-28 (`term=grove.provision`). a revival in a new operation would re-open a settled question |

⚠️ the middle four all lose for ONE reason, worth a plain sentence: **they are live
words in this repo.** a merely unused synonym costs a reader a lookup; a synonym IN
USE costs them a wrong belief.

## ⚠️ .the boundary this term must not blur

the sharpest objection to this cluster is that
`rule.require.grove-provision-as-the-only-entrypoint` forbids a second path that
drives grove state — and a "one command that provisions a box" sounds exactly
like one.

the answer is the asymmetry in the say-file, and it is testable:

> delete `git.grove.provision` and every fact it produces is still reachable by hand.
> delete `grove.provision` and it has no work at all.

so it is a SEQUENCER. it holds no bundle, no phase, no fix, and no state. its
whole content is order, exit codes, and the refusal to let a human skip a step.

⚠️ **the failure mode to watch for** is a fix that lands HERE rather than in a
bundle. the moment this skill carries a workaround, it has become the second
entrypoint the rule forbids — and it looks reasonable at the time, because a
sequencer is exactly where a "just one small step" wants to live
(`rule.forbid.deferred-provision-defects`).

## .why `grove.` prefixes it

the same reason `grove.wake`, `grove.push`, and `grove.read` carry it: the subject
is a GROVE, and a reader takes the family as a set. an unprefixed `provision` would
also collide with infra's own use of the word for the INSTANCE — a different
subject at a different layer.

⚠️ and that collision is a FEATURE at the prose level and a hazard at the contract
level. in a sentence, "infra provisions the box, we provision the tree" reads
clean. as two bare operations named `provision`, it is one word for two subjects —
the overload `rule.forbid.domain-term-synonyms` exists to prevent. the prefix keeps
the prose and kills the overload.

## .evidence

- the word already governed two always-booted rules, by filename
- the sequence it names failed twice in ten minutes as prose, measured
- four of its six rejected synonyms are LIVE words in this repo, each with a
  distinct extant sense

### ✔ .the operation FIRST RAN 2026-08-25 — what is now measured, and what is not

this cluster landed on 2026-08-26 against an operation that had **never executed a
line** (exit 126, no exec bit). so every operational sentence in it was a read of
source, and round 61 of the learner's progress log owed this marker "in the same
edit as the measurement". here it is.

**measured**, against `grove-ahbode-v20260811` — a genuinely bare box, both seats,
new instance, new host key:

| claim | verdict |
|---|---|
| plan names the steps and runs none | ✔ |
| the order is ground-then-camper | ✔ |
| step 1 wakes, then trusts | ✔ |
| step 2 pushes, then drives ONE detached apply | ✔ |
| the verdict comes from a SECOND read of the log, never the send | ✔ |
| it halts on claims rather than continue to the gate | ✔ |

**still unmeasured**: step 3 (the camper), step 4 (the gate), the 97-tolerance
loop, and the per-seat marker's refusal of a second apply. the run halted at
step 2 on a credential fact, so it never reached those paths.

### ⚠️ what the first run found, and why it argues FOR the term

the sequencer carried **four defects of its own**, and a read of source can see
none of them:

| # | defect | why a read could not see it |
|---|---|---|
| 1-3 | `>/dev/null 2>&1` on push, wake, and trust.gen | it looks like tidy output. only a FAILURE shows that the step's reason went with it |
| 4 | `grep -E '^[[:space:]]*✋'` in the claim dump | a duct runs an interactive **zsh**, which expands `[[:space:]]*` as a filename glob and halts the send with `no matches found` |

⚠️ #4 is sharpest, and it is this term's own hazard realized: the one command whose
job is to SHOW the claims showed none, and the halt underneath then said *"each is
named above"* over an empty space. a sequencer that swallows its steps' evidence
reports a step NUMBER and destroys the reason (`term=swallow`,
`rule.forbid.bare-globs-in-dual-shell-files`).

⇒ so the first run's yield was not the box. it was **four defects in the sequencer
that no amount of source-read would surface** — exactly why `term=declared` and
`term=live` are two words, and why a cluster written against a declared-only
operation must say so.

### ✔ the `rhx` path — CLOSED 2026-08-30

this section read *"it ran as `bash <path>`, never as `rhx git.grove.provision`"*, so
`rule.require.prove-the-path-the-human-runs` held only half. it now holds whole. one
command, typed the way a human types it, against a REBUILT cloud box:

```
rhx git.grove.provision boot grove-ahbode-v20260811 --mode apply --trust replace
   1. reach    wake ✔ · trust ✔ (replace)
   2. ground   push ✔ · apply ✔ ~5m
   3. camper   push ✔ · apply ✔ ~4m
   4. gate     steps 0..4 all held — 31 passed, 0 failed
exit 0
```

⚠️ every property of `rule.require.one-command-provision` held in that run: ONE apply
per seat (no second pass cleared a claim), no prompt, **zero claims on either seat's
first apply**, and a from-scratch disk — `--trust replace` was needed precisely because
the rebuild presented a new host key.

⇒ and it proves the J1 rename off-box: `git.grove.{wake,trust.gen,push,send,
ready.verify,provision}` each drove a real grove under its new name.

## .disputes

### dispute: does the glossary carry the SLUG or the CONCEPT?  —  raised 2026-08-30  —  status: OPEN
- raised.by  = the J1 collapse, driven this round
- context    = J1 renamed the seven `grove.*` skills to `git.grove.*` and renamed **one** term
               cluster to match — this one. eight siblings kept the bare form:
               `term=grove.{wake,stop,push,pull,send,read,trust,alias}`. so the glossary holds
               one prefixed term and eight unprefixed ones for a single family
               (`rule.forbid.domain-term-inconsistency`).
- claim (a)  = rename the eight to `term=git.grove.*`. one family, one form, and a reader who
               greps a slug reaches its term.
- claim (b)  = revert THIS one to `term=grove.provision`. the glossary names the CONCEPT in its
               bounded context, and `.readme.md`'s prefix rule asks for the context (`grove`),
               not the address.
- ⚠️ note     = (b) is what this cluster's own say file already states — *"an `rhx` slug is a
               NAMESPACE ADDRESS"* — so `git.` is the forest namespace ABOVE the context, not a
               second context. the round that settled J1 left the glossary at odds with its own
               rename.
- resolution = unresolved. a clean rework either way (a rename, no body change), so it is
               flagged rather than halted on. contracts keep the extant forms meanwhile.

## .see also

- `term=grove._.choice._.md` — the subject
- `term=seat._.choice._.md` — why the order is per-seat, and why ground goes first
- `term=grove.provision._.choice._.md` — the one entrypoint this drives
- `term=grove.bootstrap._.choice._.md` — the pre-repo first contact, NOT this
- `rule.require.one-command-provision` — the bar this operation exists to hold
