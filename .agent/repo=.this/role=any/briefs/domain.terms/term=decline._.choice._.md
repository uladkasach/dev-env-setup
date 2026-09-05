# domain.term: decline

term.chosen   = decline
term.kind     = verb
term.synonyms.forbidden:
- skip         (says the work was PASSED OVER, which invites "then run it anyway"; a decline
                says the question was unanswerable here — see `.reason`)
- ignore       (locates the choice in the reader's attention; a decline is a phase's verdict)
- warn         (a warning names a RISK; a decline names a fact that is correct right now)
- pass         (already means "the claim held" — the opposite of what a decline reports)
- defer        (a decline may or may not be completed later; `defer` promises a later run
                that a phase has no authority to schedule)
- n/a          (an abbreviation with no subject: it says WHICH is inapplicable, never WHY)

## .what
a phase's verdict that a question **could not be asked here**, and that this is correct —
marked `🌙`. it is the counterpart of `claim` (`✋`/`•`), and the pair is the whole reason
either word is load-bear:

| glyph | verdict | means | a human owes… |
|---|---|---|---|
| `•` / `✔` | a claim, PROVEN | the machine matches the declaration | no step |
| `✋` | a claim, REFUTED | the machine is wrong, and the fix is named | the named fix |
| `🌙` | a **decline** | the question was unaskable from here | no step |

so a decline is not a soft ✋. **it is a NON-claim**, and a run full of 🌙 is a healthy run.

## .the TWO reasons a phase declines

| reason | example |
|---|---|
| **inapplicable on this server** | `6.2.codium` on `cloud@aws.ec2` — no desktop to configure |
| **not observable from this seat** | `2.2.git` cannot judge `~/.bash_aliases`; that is `2.7.aliases`'s claim |

both are facts about the **subject**: what this box is, and what this bundle may see. no second
run of the same tree cures either, and neither owes a human a step.

## 🛑 .there is no THIRD reason — "an order fact" is a DEFECT, not a decline

👎 the shape that must never be itemized here:

> ~~**an order fact** — true later, purely by position in the tree~~
> ~~e.g. `2.2.git` (section 2) derives its identity from a credential `5.4.gh` (section 5) wires~~

**that is the defect `rule.require.one-command-provision` calls a blocker**, and it is fixed
with a MOVE of the phase, never with a better 🌙:

| the bundle | its 🌙 said | the fix |
|---|---|---|
| `2.2.git`'s identity | *"the next apply completes it; no human step is owed"* | → `5.15.identity`, after the `5.4.gh` it needs |
| `4.5.nvim`'s tree-sitter build | *"cargo arrives in `5.2.rust`"* | → `5.14.treesitter`, after the `5.2.rust` it needs |

⚠️ **why it survived two days:** an order fact is TRUE. the phase really could not converge, no
human really owed a step, and the 🌙 really did name its blocker. every clause held — and
together they described a bundle that takes TWO applies, exactly what the bar forbids. a
correct reason is what let a reader agree and move on.

⇒ **an order fact is a fact about the TREE, never about the subject.** the other two reasons
are properties of the box; this one is a property of where somebody filed a directory. that is
the tell: a verdict whose truth depends on WHERE ITS BUNDLE SITS sits in the wrong bundle.

### .the test, for any decline you write or read

> **does this decline name another bundle? then: does that bundle run BEFORE or AFTER this one?**

| it runs… | then the decline is… |
|---|---|
| **after** | a defect of order. MOVE this phase to a bundle after it — never carry the 🌙 |
| **before** | that bundle failed. this is a ✋, and it names IT — never a re-apply of this one |

⚠️ the **before** row is the sharper half. `5.10.repos` declined on an ssh key that `2.3.ssh`
lays down EIGHT sections earlier, and told a human to apply again — an instruction that finds
the same absence and prints the same line, forever.

⚠️ and when a phase MOVES, re-read every 🌙 it carries. a decline that held only because of
where its step SAT falls once the step lands elsewhere: `5.14.treesitter`'s absent-cargo 🌙
turned ✋ the moment it ran after rust.

## .what a decline OWES

a decline that only says 🌙 is worse than a ✋: it makes no claim a reader can contradict
(`gotcha.a-check-that-cries-wolf-gets-silenced`, measurement 3). so it owes:

| owes | why |
|---|---|
| WHY the question was unaskable | *"no desktop on this server"*, not *"skipped"* |
| WHO owns the fact, if anyone | *"the file is `2.7.aliases`'s claim, not mine"* |
| whether a human owes a step | a decline that hides an owed step is a `✋` in disguise |

⚠️ what a decline may **never** owe is a **later run of the same tree**. that clause is the
signature of the retracted third reason above — *"the next apply completes it"* — and it stays
a blocker however true it happens to be.

## .refs
- src/grove.provision/2.shell/2.2.git/configure.verify.sh   # a seat-scope decline at claim 3 — the file's `~/.bash_aliases` is 2.7's verdict
- src/grove.provision/2.shell/2.5.zsh/provision.upsert.sh   # a refused `chsh` — its REASON was wrong for a year; corrected 2026-08-11, see `.reason`
- src/grove.provision/5.devtools/5.10.repos/configure.upsert.sh  # no ssh key yet, so the https origin stands
- src/grove.provision/6.apps/6.2.codium/configure.verify.sh # no desktop on a cloud grove

## ⚠️ .a decline is a CLAIM about applicability, so it can be asserted

the rows above are places a decline *emits*. the harder discipline asserts one — state that a
given bundle MUST decline on a given server, and go red if it applies.

`verify.procs.grove-split.play.sh` is the reference. `1.6.procs` is three bundles for one
reason, and that reason is a line only a headless box can test:

| bundle | reaches the human by | on a grove |
|---|---|---|
| `1.6.1.finders` | stdout, which a duct reads | applies |
| `1.6.2.monitor` | `notify-send`, which needs a bus | **declines** |
| `1.6.3.earlyoom` | the kernel; no human at all | applies |

on a laptop all three apply — so a laptop run proves the bundles work and proves not one word
about **why they are three**. that is `rule.require.prove-changes-on-a-grove` at its sharpest:
the split's entire justification stays invisible where every branch is taken.

⇒ when a decline is the POINT of a design, assert it somewhere. a decline nobody checks
decays into a bundle somebody merges back.

## .reason
see the ref-level cluster beside this choice:
- `term=decline._.choice.reason.md` — the etymology, why `order fact` did NOT become its own
  term, and the 2026-08-10 measurement where a decline masked a real defect
