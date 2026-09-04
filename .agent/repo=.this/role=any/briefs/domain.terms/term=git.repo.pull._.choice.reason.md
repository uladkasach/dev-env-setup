# domain.term.choice.reason: git.repo.pull

## .etymology

`pull` is not a new word here — it was canonized the same week as `grove.pull`, for content
that moves *from* somewhere *to* here. `git.repo.pull` reuses that verb rather than mint a
synonym, and the NOUN is what tells the two apart: `repo` vs `grove`, the direct object each
one pulls.

⚠️ this replaces the old *"reuses the verb at a second SCOPE"* rationale. a scope prefix was
needed only while the two `pull`s were otherwise identical; once the object sits in the name,
no ambiguity is left for a scope to settle.

the word also matches the tool the operation actually drives — `git pull`. a human who reads
`git.repo.pull` and then reads the alias body finds the same word twice. that is the
cheapest possible etymology: the domain already said it.

## .the dispute it closes

- one retired word named TWO operations in OPPOSITE directions — its push half pushed configs
  from a checkout onto the machine, while its pull half pulled the repo from its remote
- a reader could not tell direction from the word, because the word claimed both
- the human settled it 2026-07-27: the push half becomes `grove.provision.*`, and this pull half
  becomes `git.repo.pull`

so the split is by DIRECTION, which is the one dimension `sync` erased.

## .why not the other candidates

| candidate | why it loses |
|-----------|--------------|
| `sync` | the word this replaces — bidirectional by implication, and it named both directions |
| `fetch` | git's own `fetch` is a *different* operation (no merge); to reuse it would misname |
| `update` | direction-free, and a forbidden synonym of `upgrade` — it would re-collide the pair |
| `refresh` | vague; states no source and no direction |

## .the pair it completes

| term | direction | what moves |
|------|-----------|------------|
| `git.repo.pull` | remote → here | the repo itself |
| `grove.provision` | repo → machine | the configs + tools the repo declares |

read together they narrate the whole loop a human runs: pull the declaration, then upgrade the
machine to it. under `sync` that loop was two uses of one word, and the order was not legible
from the names.

## .evidence

- `git.repo.pull` runs `git checkout main && git pull` — the remote → here direction, named
  by the tool it drives
- `grove.pull` already carries `pull` for the same directional sense at a different scope, so
  the verb is reused rather than invented
- the human's decision, 2026-07-27: "probably right, to get everything ubiquitous"

## .disputes

none open. the word was never contested — the contest was over `sync`, and this term is one
half of that settlement.
