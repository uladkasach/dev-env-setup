# domain.term.choice.reason: read (in `grove.read`)

## .etymology

`read` arrived as the natural other half of `send`. the duct is a pipe: you send into it, you
read out of it. that pairing is the oldest one in unix and it needed no invention here.

it also earns its keep against the **get/set/gen/del** quad. a grove's duct output is not a
domain object one could `get` by a key — it is a stream one **reads at a moment**. `getGroveDuct`
would imply a retrievable resource with an identity; `read` implies a look at a live surface.

## .disputes

### dispute: snapshot — raised 2026-07-26 — status: OPEN
- raised.by  = \<human\>
- claim      = rename `grove.read` → `grove.snapshot`, to match the vocabulary in
               `ehmpathy/rhachet-roles-bhrowser`. that repo names the read operation a
               **snapshot**, and its `playbook` term was adopted here on exactly that
               argument (see `term=play._.choice.reason.md`), so consistency pulls the
               same way for this half of the pair.
- counter    = three counters, none of them decisive:
               1. **the pair breaks.** `send` / `read` is symmetric — one verb in, one verb
                  out, both present tense, both four letters. `send` / `snapshot` is not:
                  one is a motion, the other a noun-shaped artifact
                  (`rule.prefer.symmetric-term-pairs`).
               2. **a snapshot implies an artifact retained.** in bhrowser a snapshot is a
                  captured page state a playbook can act upon later. `grove.read` retains no
                  artifact at all — it prints and exits. to call it a snapshot would promise a
                  durable file the operation does not produce.
               3. **the import argument is weaker here than for `playbook`.** `playbook` was
                  adopted because bhrowser had already settled a *mechanism* this repo had
                  independently rebuilt — a convergence. a browser's snapshot and a tmux
                  pane's output are not the same mechanism, so the word does not carry over
                  by the same right.
- for        = the counters are answerable. if `grove.read` were to gain a `--into <path>`
               that retains the output, counter 2 dissolves and `snapshot` becomes the truer
               word. and a shared vocabulary across repos is worth some asymmetry.
- resolution = OPEN. contracts keep `read`. the decision hinges on whether the operation is
               to retain an artifact — if it does, adopt `snapshot`; if it stays
               print-and-exit, keep `read`.

## .evidence

- the half of the same proposal that named `grove.send` → `grove.play` was **RESOLVED against**
  on inspection of bhrowser: that repo does *not* name its runner `browser.play` — it keeps
  `browser.action` and passes `--play`. so the proposal's direction was right and its words
  were not, which is precisely why this half deserves its own dispute rather than the same
  verdict (see `term=play._.choice.reason.md`).
- the operation is print-and-exit today: `git_alias_grove read <name>` dispatches into
  ductwork and returns the pane's visible output on stdout. no file is written, and no state on
  the grove changes. that fact is what holds `read` in place for now.
- a real hazard the word choice must respect: whatever the read is called, a secret must never
  travel through a duct — tmux keeps scrollback, so it lands in a capturable pane and in this
  operation's output (`plan.grove-credentials.md`). a word that suggests a *retained* artifact
  makes that hazard sound worse than it is, which is a small argument for `read`.
