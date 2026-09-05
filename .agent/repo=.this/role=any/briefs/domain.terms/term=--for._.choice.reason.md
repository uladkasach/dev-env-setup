# domain.term.choice.reason: --for

> filed as `grove.provision.for`, then `<old>.for`, then finally `--for` — all on 2026-07-27.
> the last rename is the one that matters: a term names a CONTRACT, and this contract is a
> FLAG. see `.the name is the flag` in the say-level file, and the scope dispute below.

## .the detection was WRONG for every cloud box  (found 2026-07-28)

the axis shipped with a three-branch detection, and the middle branch was false on any vm:

```sh
loginctl show-seat seat0   # "a logind seat means a screen is attached"
```

an ec2 instance carries VIRTUAL display hardware — `/sys/class/drm/card0` exists — so
systemd-logind registers `seat0`, and `systemctl get-default` even reports `graphical.target`.
a genuinely headless grove therefore detected **`local`**, which would drive it to install
firefox, cosmic, and keyd on a machine with no screen.

**why it hid for two days.** every real grove path passes `--for cloud` explicitly, so the
detection never cast the vote that settled it. it surfaced only once a checker asked the
detection DIRECTLY rather than through a caller that overrode it.

**how it surfaced.** the verify play asserted `grove_for_detect = cloud` on a real headless
box and got `local`. the verdict named no cause, so a second play reported all three branches
independently — and branch 2 alone fired. branches 1 and 3 had answered correctly all along.
(that play fell 2026-08-11 once the defect closed.)

**the lesson, which generalizes past this repo:**

> the branch tested for display HARDWARE. the domain question is whether a HUMAN has a screen
> here. a hypervisor supplies the former and never the latter.

that is a proxy-vs-truth error, the same shape as the `local`-tag abuse below
(`clone_org_repos`): a signal that correlates with the answer on the machines you happen to
have tested, and diverges on the ones you have not. the two surviving branches both ask the
real question — one about a LIVE session (`DISPLAY`), one about DECLARED intent (a compositor
on disk).

the cure deletes the branch rather than special-case ec2. a proxy wrong for a whole CLASS of
machine takes no per-machine patch.

## .etymology
born 2026-07-26, when the repo collapsed its TWO install lists into one. before that day,
`install_env._.sh` installed a local machine and `install_env.grove.sh` installed a headless
box — two lists of the same steps, which drifted apart step by step.

one list needs an axis to say which machine a run is for. the human named that axis `--for`,
with the values `cloud` and `local`, and the matched step tags `any | local | cloud`.

`for` beat `scope`, `target`, and `mode`:
- `scope` reads as "how much", not "which machine" — and the human rejected it in the same
  round it was first reached for
- `target` is overloaded across build tools (a make target, a deploy target)
- `mode` already names the plan/apply axis in this repo's skills; reuse would be a straight
  overload (`ubiqlang.ambiguous-from-overload`)

`for` reads as the plain english question the flag answers: *what is this run for?*

## .disputes

### dispute: cloud vs grove  —  raised 2026-07-26  —  status: RESOLVED (keep `cloud`)
- raised.by  = <traveler>
- claim      = `grove` is already the itemized, canonical word for "a machine (host) that
               holds trees" — i.e. exactly the cloud box this value names. so
               `--for grove|local` would use the canonical term, and `--for cloud|local`
               risks a synonym drift that `rule.forbid.domain-term-synonyms` forbids in a
               contract (and a cli flag IS a contract).
- counter    = the two words are different parts of speech, so they do not compete:
               - `grove` is a **noun** — it names the machine itself. you wake a grove,
                 you push to a grove, a grove holds trees.
               - `cloud` is an **adj** — it says WHERE a machine lives, which is what an
                 axis value must do. `--for cloud` reads "for a cloud machine".
               a noun cannot fill the slot cleanly: `--for grove|local` pairs a noun with
               an adj, which breaks `rule.prefer.symmetric-term-pairs`. `cloud|local` is a
               matched adj pair, read at a glance, and it extends (a future `--for wsl`
               or `--for container` sits in the same shape; `--for grove` does not).
               the human settled on `cloud|local` explicitly in this round.
- resolution = keep `cloud` as the ADJ value; keep `grove` as the NOUN for the machine.
               record `grove` as a forbidden synonym FOR THIS AXIS only — it stays fully
               canonical in its own noun slot. the two coexist without overload because
               they answer different questions: `grove` = which machine, `cloud` = where.

### dispute: cloud vs grove, RE-RAISED  —  2026-07-27  —  status: OPEN again
- re-raised.by = the human, who reached for the noun unprompted a day after they settled on
                 the adj: *"why not grove.provision --for grove"* — the verb they said is the
                 one the repo carried then; `grove.provision` is its successor, and the quote
                 is left as spoken (`rule.require.briefs-obey-the-prose-rules` exempts a
                 verbatim quote from a rename)
- why it matters = the resolution above stood on reason (adj-to-adj symmetry, room for a
                 future `--for wsl`), and the human agreed to it that round. but a term a human
                 does not reach for will drift, and the strongest evidence about which word is
                 right is which word gets SAID. one reach is not a verdict, so this is logged
                 rather than flipped.
- the case unchanged for `cloud` = `grove` is a noun and `local` is an adj; `grove|local`
                 pairs mismatched parts of speech (`rule.prefer.symmetric-term-pairs`), and a
                 third value (`wsl`, `container`) sits cleanly beside `cloud|local` but not
                 beside `grove|local`
- the case now for `grove` = the value's real referent in this repo IS a grove, and `grove`
                 is already the canonical noun. a human who says "upgrade the grove" and then
                 must type `--for cloud` performs a translation, which is the friction a
                 ubiqlang exists to remove
- resolution = RESOLVED 2026-07-27, SAME DAY, in favor of `cloud`. the human closed it in
               four characters: *"so did you fix it all? `--for cloud|local`"*. they wrote the
               adj pair themselves, which settles it harder than round one did: the first time
               they ACCEPTED a reasoned argument; this time they REACHED for the word
               unprompted. the earlier `--for grove` reach reads, in hindsight, as the noun
               said loosely in prose rather than a claim on the flag.
- the lesson kept = a single reach is not a verdict. had I flipped the term the moment the
               human said "grove", I would have churned a settled word on one loose mention,
               then reverted it an hour later. the dispute mechanism made the difference: log
               the reach, hold the contract, let the next reach decide.

### dispute: does the axis extend to `grove.provision`?  —  raised 2026-07-27  —  status: OPEN
- raised.by  = the human: *"--for $what is always carried through even into each subset"*
- claim      = `for` is presently scoped to ONE operation (`grove.provision.for`). the human
               asks for it on `grove.provision` too, and carried into every slice — which would
               make it a **tree-wide axis** (`<old>.for`), not an install-only one. the
               term would then be prefixed at the context, not the operation.
- evidence for = the axis answers "which kind of machine", a question every provision operation
               faces. `grove.provision.grove` exists precisely because the alias suite lacked
               the axis, so it grew a hand-rolled substitute (see the dispute at
               `term=grove.provision._.choice.reason.md`)
- the cost   = the aliases must become shell functions before a flag can carry; an `alias`
               appends its arguments to the LAST member alone
- resolution = RESOLVED 2026-07-27 (adopt the wider scope). the human: *"fix it all"*. the
               term RENAMES `grove.provision.for` → `<old>.for`, and the axis moves out of
               `install_env._.sh` into its own `src/grove.for.sh`, which both operations now
               source. the same move deleted the entrypoint's private `_detect_for` copy — a
               second copy of an axis is the same defect as a second copy of a list.
- what the wider scope proved = both places ALREADY needed the axis. its absence from the
               alias suite is precisely why that suite grew `grove.provision.grove` — a
               hand-rolled substitute for a flag it could not carry. the term did not widen to
               fit a preference; it widened to the size it always was.

## .the options weighed

| option | what it reads as | verdict |
|--------|------------------|---------|
| `--for cloud\|local` | a matched adj pair that says where the machine lives | **chosen** |
| `--for grove\|local` | a noun paired with an adj — asymmetric | rejected |
| `--scope any\|desk` | "how much", not "which machine"; `desk` is jargon | rejected by the human |
| `--mode cloud\|local` | overloads `mode`, which already means plan/apply | rejected |

### ⚠️ `scope` loses FOR THIS AXIS ONLY — it stays canonical elsewhere

that rejection is narrow, and a reader took it too widely on 2026-08-02. when the human
proposed `rhx keyrack get --scope github://org/<org>`, the robot pushed back on the NAME,
partly on the grounds that this term had already rejected `scope`.

that was wrong, and this file already held the refutation — its own boundary section uses the
word correctly:

> for `clone_org_repos` the honest axes were already present: the **SCOPE of the machine's
> github token**, and `GROVE_GIT_ORGS`

so one file already held both senses, and they do not compete:

| the word | the question it answers | where it lives |
|---|---|---|
| `--for` | which KIND of machine is this run for? | this axis |
| `scope` | what may this CREDENTIAL reach? | a credential grant |

*"how much"* is precisely the wrong question for a machine axis and precisely the RIGHT one
for a credential — it is what a jwt `scope` claim means. so `scope` is a forbidden synonym
**for this axis**, in the same bounded way `grove` is: fully canonical in its own slot.

**the lesson that generalizes:** a rejection recorded in a term file binds *that term's slot*,
never the whole repo. read it wider and one settled choice vetoes an unrelated one — here it
nearly vetoed the correct name for a contract the human had already reasoned out.

## .evidence
- the collapse of two lists into one created the need — with two files, the filename carried
  the axis implicitly, so it needed no word
- the step tags must mirror the flag, else a reader holds two vocabularies for one axis. the
  human corrected an earlier `step any|desk` to `step any|local|cloud`, which proved the flag
  and the tag must share one set of words
- a third value is foreseeable (a container, a wsl box), and `cloud|local` accepts one
  where `grove|local` would force a second noun into an adj slot
- `configure_ssm_agent_resume` was the first genuinely `cloud`-only step: a local machine runs
  no ssm agent, so an `any` tag would be a polite lie that leaned on a no-op

### the `cloud` tag now has ZERO members — and the axis still stands (2026-07-27)

`configure_ssm_agent_resume` **fell** the day after it was written: `ahbode/infrastructure`
bakes the hibernate/resume repair into the grove image itself, and a machine-lifecycle concern
belongs to whoever builds the image, not to a dev-env repo (`rule.require.bounded-contexts`).

so the one step that motivated the `cloud` tag is gone, and no step carries it today.

**the tag stays anyway, deliberately.** a taxonomy names what a step COULD be, not what
happens to exist this week. two reasons it earns its place with zero members:

1. the axis is real — a cloud-only concern is plainly conceivable, and the next one arrives
   unannounced
2. delete the value and the next such step falls back into a dishonest `any` — the exact
   defect the human's `any|desk` → `any|local|cloud` correction fixed in the first place

this entry stays as written, because the deleted step remains the clearest *explanation* of
what a `cloud` tag is for — even though it is no longer an example of one.

### the axis has a BOUNDARY, learned by abuse (2026-07-27)

`--for` answers exactly one question: **which KIND of machine is this step for?** it does not
answer *is this step safe here*, *is this step cheap here*, or *do i want this here today*.

the day it was written, that boundary broke. `clone_org_repos` carried a `local` tag and a
recorded reason: a bulk clone of three orgs' PRIVATE source onto a remote box is too much
exposure. the concern was real. the axis was wrong. the human caught it in one line —

> why would clone_org_repos be local only? its expected to run on cloud

and the correction is the term lesson: a grove IS a dev machine — it exists to hold trees — so
it needs the same repos a laptop does. a safety preference encoded in a machine tag makes the
taxonomy **lie**: it states that a grove has no use for its own repos, which is false.

the tell that generalizes: **a `local` tag defended by a reason that never mentions the machine
is a smell.** the concern belongs on some other axis. round eleven found the mirror image — an
`any` tag defended by "it no-ops anyway" — so the pair now reads:

| the tag | the bad defense | what it really means |
|---------|-----------------|----------------------|
| `any`   | "it no-ops on the other machine" | the taxonomy lacks a value |
| `local` | "it would be unsafe over there" | the concern belongs on another axis |

for `clone_org_repos` the honest axes were already present: the SCOPE of the machine's github
token, and `GROVE_GIT_ORGS` (which orgs a machine asks for). both are levers a grove can pull;
a machine tag is not.

**a second defect fell out of the first.** the retag exposed `install_gh_cli`, tagged `local`
for the reason "needs a human's identity or an interactive auth". that covers only its AUTH
half — the BINARY needs no human. one function conflated the two, so a grove got neither, and
the newly-`any` `clone_org_repos` had no `gh` to call. the cure splits the function rather than
re-tags it: binary always, token if the env holds one, a loud named failure if a headless box
has neither.

which sharpens the test one more turn: before you tag a step, ask whether it is **one** step. a
step that does two acts with two different machine answers takes no honest tag at all — `local`
lies about one half and `any` lies about the other. the tag is not the defect there; the
conflation is.
