# domain.term.choice.reason: play

## .etymology
adopted 2026-07-26 from `ehmpathy/rhachet-roles-bhrowser`, which had already settled the word.
there it is `src/playbooks/login.play.ts`, run via `browser.action --play login`, governed by
`rule.require.playbooks-over-adhoc`.

the word arrived here by a near-miss worth a record. i had independently built the same
mechanism for a grove — a one-step guard on `--what`, plus a file to hold the many-step case —
and named the artifact a **play**, in a dir called `.agent/.play/`. the human then asked
whether it should match "the bhrowser terms". reading that repo showed:

- the artifact is a **playbook**, not a play
- the read operation is a **snapshot**, not a snap
- the runner keeps its own verb (`browser.action`) and takes the playbook as `--play <name>`
- the rule against ad-hoc commands was already written, with a stronger why than mine

so this was a **convergence**, not an invention: two repos reached the same mechanism
independently, and the older one already held the vocabulary. the renames followed
(`<name>.sh` → `<name>.play.sh`, and the dir renamed to match).

## .why `playbook` over `play`

- **`play` is the flag, `playbook` is the artifact.** bhrowser splits them that way and it
  reads correctly: you pass `--play <name>` to run a playbook. one word for both would blur
  the file and the argument that names it.
- **`play` is also a verb**, so a bare `play` invites the read "to play" — which pulls toward
  a `grove.play` operation that does not exist (see the dispute below).
- **a playbook is a set piece.** the metaphor is exact: rehearsed, written down, repeatable —
  the opposite of an improvisation typed at a prompt.

## .why not the s-word

the obvious alternative is on this repo's forbidden-terms blocklist
(`rule.forbid.term-script`): it conflates command, procedure, operation, and mechanism. the
blocklist hook caught the first TWO drafts of this very file, which is a neat proof the rule
earns its keep — the word is so reflexive that it slipped in twice while a term file was
authored ABOUT careful word choice. (this paragraph names it obliquely on purpose; the hook
blocks the literal even here, and being unable to quote a forbidden word inside its own
glossary entry is itself a small canon gap worth a note.)

## .disputes

### dispute: a play is SCRATCH by construction — raised 2026-09-02 — status: RESOLVED (two dirs, one term)
- raised.by  = the artifact, not a person — a discrimination probe had no lawful home
- claim      = `.what` said a play is scratch, gitignored, never committed. `term=exhibit`
               drew the consequence in its own voice: *"a clamp may not be a play"*.
- counter    = `rule.forbid.repair-plays` exception 2 REQUIRES a permanent, tracked
               discrimination probe — it breaks a subject on purpose and confirms the check
               reddens, which no read of a healthy box can produce. so the two rules demanded
               opposite things, and the gap was filled by a third dir, `.agent/playbooks/`,
               which the repo had already forbidden. that dir sat outside both runners' reach
               AND outside `shell.syntax.verify`'s walk, so a play there was unparsed,
               undrivable by slug, and silent when absent.
- resolution = the term keeps ONE word and gains a second HOME. `.play/temporary/` is
               gitignored scratch — the default, and almost every play. `.play/permanent/` is
               tracked, and holds exactly one kind: the discrimination probe. no third dir.
               `.agent/playbooks/` is forbidden by name, and `term=exhibit`'s *"a clamp may not
               be a play"* is retired — the DIR is the test, never the suffix.
- ⚠️ what the fix nearly missed = the move dropped 5 files out of `shell.syntax.verify`'s
               walk, because that reader was keyed on where the set USED to live. a reader
               keyed on a set's old home reports ✔ over a set it can no longer reach
               (`gotcha.a-check-that-cries-wolf-gets-silenced`, q11). the walk was widened;
               266 → 271 files parsed.

### dispute: play — raised 2026-08-31 — status: RESOLVED (adopt `play`; `playbook` is the forbidden synonym)
- raised.by  = the contracts, not a person — the repo had already drifted, in four places
- claim      = the canonical word is **play**, not `playbook`, and it always was here. the
               glossary's own four child terms are `play.await`, `play.prove`,
               `play.rollback`, `play.verify` — every one rooted on `play`. the dir is
               `.play/temporary/`. the flag is `--play`. the skill's variable is
               `PLAY_DIR_REL`. the filename infix is `.play.sh`. **`playbook` survives in
               exactly one contract: the name of this term file.**
- counter    = `.why playbook over play` above argues the split reads correctly — the flag is
               `--play`, the artifact is a `playbook`. that argument is sound in the abstract
               and was never obeyed: no contract in this repo has ever spelled the artifact
               `playbook` outside the deleted `.agent/playbooks/` dir name.
- resolution = **`play` is canonical.** a glossary that forbids a word its own four child
               terms are built from is not a glossary, it is a drift with a file around it
               (`rule.forbid.domain-term-synonyms` — one concept, one word, everywhere a
               contract can be read). `playbook` joins the forbidden list. the cluster is
               renamed `term=play.*`, which also makes the family read as one:
               `play` → `play.prove` / `play.verify` / `play.await` / `play.rollback`.
- ⚠️ what did NOT change = the bhrowser convergence in `.etymology` stands, and so does the
               `--play` flag it settled. bhrowser names the ARTIFACT `playbook`; this repo
               names it `play`. that is a deliberate divergence on one noun, and the reason
               is that four child terms and five contracts here already say `play`.

### dispute: grove.play as the operation — raised 2026-07-26 — status: RESOLVED (keep grove.send)
- raised.by  = <human>
- claim      = rename `grove.send` → `grove.play` and `grove.read` → `grove.snap`, to match
               the bhrowser vocabulary.
- counter    = the direction was right, the words were not. bhrowser does NOT name its runner
               `browser.play` — it keeps `browser.action` and passes `--play`. the verb names
               the ACT; the playbook is the ARGUMENT. and `grove.send --what 'uname -a'` must
               still read correctly for the one-step case, where "play a single command" does
               not. `snap` likewise loses to `snapshot`, the word bhrowser actually uses.
- resolution = keep `grove.send` with `--play`, which already matched bhrowser exactly.
               adopt `playbook` for the artifact. the `grove.read` → `grove.snapshot` half of
               the proposal is a SEPARATE, still-open dispute — see `term=grove.read`.

## .evidence
- bhrowser's `rule.require.playbooks-over-adhoc` names four costs of an ad-hoc command that i
  had also found (unreviewable, unrepeatable, uninspectable, undiffable) plus one i had NOT:
  **reuse across code and robo** — a prod scraper imports the same playbook a robot ran, so a
  robot's discovery is elevated into production rather than thrown away. that is a stronger
  why than reviewability, and it is the reason the term is worth importation rather than
  reinvention.
- the mechanism was forced by real friction: this session sent a grove a chain of
  `ls; cat; echo; systemctl ...` probes that no human could review, and the repo's pretooluse
  hooks read only the OUTER command — so each step inside `--what` reached a machine
  unexamined. the human's ask ("reject multistep unless in a play dir") named the fix.
- `audit.creds.play.sh` proved the value at once: as a file it was reviewed, and a
  **false positive was caught in it** — a filename-based filter had counted
  `authorized_keys` as a private key, which inverts a security finding. that error would have
  been invisible inside a one-liner.
