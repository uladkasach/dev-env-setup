# rule.avoid.narrate-obvious-choices

## .what

do not add a `.why` comment block for a choice a reader would never question —
especially one the human just handed you as a direct instruction. make the edit;
leave the comment out.

## .why

this repo's comment discipline is unusually rich: `.what` / `.why` headers,
`⚠️` for hard-won lessons, dated evidence, named fixes. that richness is what
makes the comments **worth a read** — and it only survives if the bar stays high.

every comment on an obvious choice spends the reader's attention without a
return, and dilutes the ones beside it. a file where every line is annotated is a
file where no annotation stands out, which is the same as a file with none.

## .the trigger

the human said "install rhachet first, btw" about three `pnpm install -g` lines.
the edit was made — and a twelve-line `⚠️ .why RHACHET FIRST` block was added
beside it, plus a twin note in the bundle's `_.sh`. the reply:

> you dont need to list comments about rhachet being first / just do it / silently

the sequence was a preference, stated plainly, that no future reader would fight.
it needed the change and not the essay.

## .the test

ask of the comment, not the code:

> would a future reader be SURPRISED by this line, or hit a bug without the note?

- **no** → write no comment. the code says it
- **yes** → write it, and say what the surprise is

a second, sharper form: **has this actually bitten someone?** the `⚠️` blocks
that earn their space in this repo all name a real incident — a run that hung 57
minutes, a font that reported absent while installed, a config that installed
from the wrong worktree. a comment with no incident behind it is a guess about
what a reader will want.

## .what still deserves the full treatment

this rule narrows the bar; it does not lower it. keep the rich comment when:

- a **defect was measured** — name it, date it, show the numbers
- a **non-obvious constraint** forces the shape (a sandbox path, a tty prompt, an
  api that lies)
- an **inversion** — the intuitive answer is the wrong one, as with terminfo on
  the remote box
- a **decision a reader will want to undo** — say why it holds, so they can judge

## .the shape of the mistake

the tell is a comment that argues for a point nobody disputed. it usually opens
with a superlative or a defense of what order two lines sit in:

```sh
# 👎 nobody was about to question this
# ⚠️ .why RHACHET FIRST, before either brain
#      rhachet is what every skill in this repo is driven through — and the
#      one that would repair a failed brain install. ...
pnpm install -g rhachet || return 1

# 👍 the line is its own account
pnpm install -g rhachet || return 1
```

## .enforcement

- a `.why` block on a choice with no incident, constraint, or inversion behind
  it = **nitpick**
- a comment added to justify a change the human just requested = **nitpick**

## .see also

- `rule.require.what-why-headers` — the discipline this rule keeps sharp
- `rule.require.timeless-comments` — the other way a comment goes bad: it reacts
  to a conversation rather than states what is
- `rule.require.exemptions-name-their-trigger` — the inverse case, where a note
  IS mandatory

