# domain.term: git.repo.pull

term.chosen   = git.repo.pull
term.kind     = verb
term.synonyms.forbidden:
- sync              # named this AND its opposite — see `.why not sync`
- devenv.pull       # ⛔ the word `devenv` is forbidden repo-wide (2026-09-02)
- repo.pull         # the bare form; it drops the `git.` family prefix
- fetch
- download
- refresh
- update

## .what
update this repo's own checkout on this machine from its remote
(`git checkout main && git pull`). content moves **remote → here**.

## 🛑 .the pair it completes, and why the NOUN carries the split

| operation | pulls | from |
|---|---|---|
| `git.repo.pull` | a **repository** | its git remote |
| `git.grove.pull` | files off a **grove** | that machine, over a duct |

both are `pull`, and the verb is the same verb. what differs is the **direct object**, so the
noun is what tells them apart — `repo` vs `grove`.

⚠️ this retires the old *"a second `pull` cluster, in a separate SCOPE"* rationale. that
framing needed a bounded-context prefix because the two `pull`s were otherwise identical; once
the noun sits in the name, no ambiguity is left for a scope prefix to settle.

## .why `git.` and not the bare `repo.pull`

it joins an extant family — `git.repo.get`, `git.repo.test` — so every operation whose subject
is a repository shares one prefix and one autocomplete stem
(`rule.require.order.noun_adj`). the bare `repo.pull` names the same act and sits outside the
family that already owns the noun.

## .why not `sync`
`sync` named this **and its opposite** — the retired sync half — it*` pushed configs repo →
machine. one word, two directions. `pull` states the direction, so `git.repo.pull` and
`grove.provision` can no longer be read for each other.

## .refs
where the term is declared / used:
- `src/bash_aliases.sh`   # the alias, and the first half of the loop:
                          #   `git.repo.pull && grove.provision`

## .reason
see the ref-level cluster beside this choice:
- `term=git.repo.pull._.choice.reason.md` — etymology, the dispute it closes, evidence
- `term=grove.pull._.choice.reason.md` — the verb's own etymology, recorded once
