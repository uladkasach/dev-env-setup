# domain.term: fix-text

term.chosen   = fix-text
term.kind     = noun
term.synonyms.forbidden:
- remediation
- suggestion
- next steps
- the fix

## .what

the imperative repair line a check prints beside a `✋` — what a human must **do**, never
what broke.

it is the one part of a check's output a human ACTS on, which is what parts it from its
three peers:

| word | holds | the human… |
|---|---|---|
| `claim` | what the bundle asserted | — |
| `verdict` | ✔ / ✋ / 🌙 | reads |
| `detail` | the error strings | diagnoses from |
| **`fix-text`** | the command to run | **runs** |

## 🛑 .a fix-text may only assert what its author can KNOW

a wrong verdict is cheap — one read disproves it. a wrong fix-text is not: a human pastes
it, and the state it creates is indistinguishable from the state a right one would create.

⇒ so where a fact is unknown at the branch that prints, the fix-text **omits it** rather
than defaults it. the shorter form is the honest one.

⚠️ the trap is a **constant** — a value true of every case the author has seen, and false
of the case the branch exists for. see the `.reason`.

## .refs

- `src/grove.provision/5.devtools/5.16.keys/configure.verify.sh` — the five-cause block; a
  fix-text that named four sent a human to a command that touched none of the fifth
- `.agent/repo=.this/role=any/skills/git.grove.auth.keys.set.sh` — three of the four
  measurements in the `.reason` are inline there
- `term=detail._.choice._.md` — a peer, and it already cites this word in its `.refs`

## .reason

see the ref-level cluster beside this choice:
- `term=fix-text._.choice.reason.md` — etymology, the four measurements, the boundary question
