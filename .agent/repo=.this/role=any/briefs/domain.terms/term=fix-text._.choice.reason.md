# domain.term.choice.reason: fix-text

## .etymology

the repo already prints the label. every check in this tree writes `fix:` beside a `✋`, and
has since before the word was itemized — so the noun is read off the surface rather than
invented for it.

`-text` because it is TEXT a human reads and pastes. that half is load-bear: the value of a
fix-text is that a human can act on it without a decode, which is also the whole reason a
wrong one is expensive.

chosen over:

- **`hint`** — ⚠️ NOT forbidden, and the distinction is a BOUNDARY rather than a synonym.
  `rule.require.failloud` (ehmpathy/mechanic, booted in this repo) prescribes `hint:` as a
  FIELD in a `HelpfulError`'s metadata. a field is carried by a program; a fix-text is pasted
  by a human. to forbid the word would collide with an imported rule that owns it.
- **`the fix`** — ambiguous, and the ambiguity is the expensive kind. **the fix is the CHANGE;
  the fix-text is the INSTRUCTION.** a round that conflates them corrects the explanation and
  leaves the defect — the exact shape `rule.forbid.deferred-provision-defects` forbids.
- **`suggestion`** — too weak: a fix-text is the repair, never an option. and
  `term=prompt-suggestion` already holds that word for a different concept, so the bare form
  would be an overload (`rule.forbid.domain-term-ambiguity`).
- **`remediation`** / **`next steps`** — jargon, and neither says who acts.

## .why the constraint is a PROPERTY of the term, not advice beside it

> **a wrong verdict is cheap. a wrong fix-text is not.**

a verdict is disproved by one read — the reader looks at the subject and the two disagree.
a fix-text is disproved by nobody, because a human runs it and it works. the state it creates
passes every later check, and no reader can part it from the state a right fix-text would
have created.

⇒ that asymmetry is why the term carries a rule in its own `.what`, where its peers carry
none.

## .the four measurements

each is a fix-text that was **actionable, plausible, and wrong**. none was caught by a check.

### m.1 — 2026-08-10 · a repair that DESTROYS what it was called to repair

the placer's local read answered empty and the fix-text named `keyrack set`. the session had
simply lapsed.

`keyrack set` has no entry-only mode, so a human who followed it would have **re-pasted over
a live value to cure a lock** (`term=entry`). the repair is `keyrack unlock`.

⇒ the branch now reads stderr for `locked` and prints the unlock. stderr is safe to hold — it
carries a STATUS, never the value.

### m.2 — 2026-09-07 · a printed command that could not run where it was printed

the success path printed a bare `rhx grove.provision …`. the grove answered
`no skill "grove.provision" found in any linked role`.

a duct pane sits at `$HOME`, and rhachet locates a git root before dispatch — so a bare remote
`rhx <repo-skill>` finds none. the shape that works is `env -C $HOME/<repo> rhx …`.

⚠️ the skill's own header declared `KR_REPO` for exactly this, and every REAL call it made
used it. only the PRINTED string ignored it — `gotcha.a-check-that-cries-wolf-gets-silenced`
m.9, one fact with two holders, and the cheap holder drifted.

### m.3 — 2026-09-07 · a cause list that was true of a SET that had grown

`5.16.keys`' verify named four causes for an EMPTY read, and its fix-text sent a reader to
`keyrack list` and an unlock. a fifth cause had landed that hour — a key whose `get` MINTS its
value, so no replica can be placed and neither command touches it.

⇒ a list of causes is a **claim about a set**, and this set grew (q11). it is five now, and
the fifth carries its own command.

### 🛑 m.4 — 2026-09-07 · a CONSTANT, true of every case its author had seen

the absent-path branch printed `rhx keyrack set … --vault os.secure`. `os.secure` infers
`PERMANENT_VIA_REPLICA`.

so for a key that ought to be `EPHEMERAL_VIA_GITHUB_APP` and is absent on this box, the
fix-text told a human to store a pasted token as a **permanent replica**. it works today. it
is wrong by construction. and a byte-count verify stays green over it forever.

**the skill could not know the mech, and the branch proves it:** a `5.16.keys` row is
`<org>:<env>:<key>` and carries no mechanism, and that branch is reached only when the rack
read answered EMPTY. the unknown is the branch's own precondition.

⇒ **the trap is that `$KR_VAULT` was a CONSTANT** — true of every row the skill had ever
placed, and false of the row in front of it by definition. a constant reads as a safe default
precisely because it has never yet been wrong.

⇒ the repair is an OMISSION. keyrack infers the mech from the vault and ASKS when it cannot,
so the bare form is both shorter and the only honest one.

⚠️ 📜 and it was found by a human's question — *"does this machine failfast if the requested
key does not exist?"* — never by a check. the branch had never been exercised, because every
row this box holds is readable (`gotcha.a-short-question-is-a-found-defect`).

## .disputes

### open: the boundary — raised 2026-09-07 — status: OPEN

`rule.require.boundary-qualified-terms` asks *"$word, of WHAT?"*, and this one answers in one
word: **of a verdict**. by that rule the filename is owed as `term=verdict.fix-text`.

it is flat anyway, on purpose, and the reason is recorded rather than skipped: **every peer in
this family is flat** — `claim`, `verdict`, `detail`, `marker`, `disposition`. a lone
qualification would part this term from five that share its boundary exactly, and the rule
forbids the bulk rename that would settle them together.

⇒ so the question is not *"does this term want a boundary?"* but *"does this FAMILY want
one?"* — which is a larger call than one round should make. left open, and named here so the
next traveler does not read the flat name as an oversight.

## .evidence

- `.agent/repo=.this/role=any/skills/git.grove.auth.keys.set.sh` — m.1, m.2, m.4 inline
- `src/grove.provision/5.devtools/5.16.keys/configure.verify.sh` — m.3, and the five-cause block
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.9 (two holders) and q11 (a set that grew)
- `gotcha.a-short-question-is-a-found-defect` — how m.4 surfaced
- `term=detail._.choice._.md` — the peer that already cited this word before it was itemized
