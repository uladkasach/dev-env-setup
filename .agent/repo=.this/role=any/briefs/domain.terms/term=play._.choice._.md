# domain.term: play

term.chosen   = play
term.kind     = noun
term.synonyms.forbidden:
- playbook     (the word this term drifted from — see the dispute in its `.reason`)
- runbook
- recipe
- macro
- batch
- snippet
- adhoc

## .what
a multi-step command, written down as a reviewed file, so it can be read before it touches a
machine and re-run by name afterward.

## 🛑 .a play is SCRATCH — that is the whole of its lifespan
`.play/temporary/<name>.play.sh`, and that dir is **gitignored**. a play is written to answer
one question and then discarded.

⚠️ one narrow exception is TRACKED, in `.play/permanent/`: a **discrimination probe**, which
breaks a subject on purpose and confirms the check reddens. that one is a clamp, so its
absence must not be silent (`rule.forbid.repair-plays`, exception 2). there is no third dir.

⇒ so a play is **never a durable claim about this repo**. what a play PROVED belongs in a
brief, stated inline as a measurement. what a run must prove belongs in
`git.grove.provision test`.

⚠️ the gitignore is not a convenience, it is the enforcement: a play that is never committed
cannot rot into a **clamp nobody runs**, and a check earns its keep by RUNNING, not by a seat
in a directory (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.13).

⇒ and that retires `term=exhibit` for this artifact kind. an exhibit is a spent measurement
kept as if it were coverage; a play that is never committed cannot become one.

⚠️ **a committed skill may NOT shell out to a play.** the play is absent on a fresh checkout,
so the skill breaks. if the body is worth a name, inline it — `git.grove.push.verify` is the
worked example.

## .refs
where the term is declared / used:
- .gitignore                                             # the enforcement that keeps a play scratch
- .agent/repo=.this/role=any/skills/git.grove.send.sh    # `--play <name>` + the one-step guard on `--what`

notable examples — the verb that leads each name says what it does to the box:
- hibernate.probe.before / .after     # `probe`   — capture state, then judge it later
- verify.tree.parity                # `verify`  — read outcome, assert a verdict
- verify.swap.hibernate-safe          # `verify`  — reads the DECLARED state, never the live
- verify.swapfile.step-defers         # `verify`  — drive a guard, assert it held
- diagnose.swap.hibernate             # `diagnose`— report facts, assert NO verdict
- prove.bundles.plan-apply-apply      # `prove`   — drives `grove.provision`, to OBSERVE it
- prove.tree.fixed-point              # `prove`   — drives the whole tree, then judges it
- await.grove.provision                # `await`   — poll for a sign-off line, bounded

the `diagnose` / `verify` split is load-bear: a `verify` play judges and may exit 1, while a
`diagnose` play only reports. `diagnose.swap.hibernate` was written precisely because a
`verify` play had asserted a verdict from a guess — so the facts had to be read before any
verdict could be trusted again.

the `verify` / `prove` split is the second one, and it is about the WRITE: a `verify` reads the
box and must not mutate it, while a `prove` drives real runs because its claim is about what a
run DOES, not about what the box IS. see `term=play.prove._.choice._.md`.

`await` sits outside both splits, because its SUBJECT differs: the others ask a question of
the machine, while an await asks whether a run has reached its sign-off. it judges no claim and
its bound is never a verdict — see `term=play.await._.choice._.md`.

## 🛑 .the hard bound on EVERY verb above — a play may never write

**a play may NEVER write machine state.** if it would install, configure, create, or "fix"
one single item, it is a **bundle** under `src/grove.provision/`, and the whole procedure
stays three steps: ssh in, push, `grove.provision`.

🛑 `repair` is not a fifth verb here, and none may be added under any name.

`prove` is the one verb that may run a command which changes the box, and only by a call INTO
the inventory (`grove.provision`, a test suite) — never a write of its own.
see `rule.forbid.repair-plays`.

⚠️ there is exactly ONE exception, and it moves a box the other way: a `rollback.*` play, used
in development to un-converge a test box so a bundle's first apply can be re-tested. it is
bounded by four conditions and its healthy population is ZERO — see `term=play.rollback`.

## .the rule it enforces
`grove.send --what` takes ONE step. a chained one-liner (`;`, `&&`, `||`, a newline) is
REFUSED, and the error names the playbook to write instead. a pipe is one step, so it passes.

## .the imported canon
this term is NOT this repo's invention — it is adopted from `ehmpathy/rhachet-roles-bhrowser`,
which declares `src/playbooks/<name>.play.ts`, runs them via `browser.action --play <name>`,
and states the same rule as `rule.require.playbooks-over-adhoc`. the word, the `.play.` infix,
and the `--play` flag all match on purpose.

## .why it is bare, not `grove.playbook`
a playbook is an artifact KIND — like a brief or a skill — not an operation scoped to one
domain object. it lives beside `briefs/` and `skills/`, and it could be sent anywhere a
command can be sent. bhrowser holds the same word for a browser, which is the proof it spans
contexts rather than belongs to one.

## .the family
`play` roots four child terms, one per verb a play may lead with:
`term=play.prove` · `term=play.verify` · `term=play.await` · `term=play.rollback`.

⚠️ that family is what settled the word. a glossary cannot forbid the root its own children
are built from.

## .reason
see the ref-level cluster beside this choice:
- `term=play._.choice.reason.md` — etymology, disputes, evidence
