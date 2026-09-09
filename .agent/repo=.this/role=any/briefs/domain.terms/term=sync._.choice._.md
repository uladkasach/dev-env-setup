# domain.term: sync

term.chosen   = ⛔ RETIRED — see `.the retirement` below
term.kind     = verb
term.status   = RETIRED 2026-07-27 (human), re-confirmed 2026-09-07

## ⛔ .the retirement

this cluster was authored 2026-09-03 against the `sync.devenv.*` alias family. **that family no
longer exists** — all 15 aliases plus the `sync.devenv` aggregate were deleted from
`bash_aliases.sh`, and the human had already retired the word months earlier:

> ⛔ RETIRED 2026-07-27 (human). one word, two OPPOSITE directions, and it collided with the core
> verb. its push half became `grove.provision.*`, its pull half `git.repo.pull`.
> — `domain.terms/.readme.md`, `### retired`

so the cluster re-minted a word the glossary had already buried, and it did so because its author
read the live alias file rather than the retired index. ⚠️ **an extant contract is evidence a word
is USED, never evidence it is CHOSEN** — and a retired word can outlive its retirement in code for
months.

⇒ what a `sync.devenv.nvim` used to do is now `rhx grove.provision --what 4.5.nvim --mode apply`.

## ✅ .the hazard that still holds — a copy is not a delivery

a sync **reports success for a copy, never for a delivery**. those come apart whenever the source
path is wrong:

```
• neovim config synced          ← printed after a copy of the WRONG file
```

measured 2026-09-03: a fix for an nvim leak sat in a worktree for a day while `sync.devenv.nvim`
read from the main clone. every run reported success, and every run delivered the old file.

> a copy's report answers *"did a copy happen?"* and the human reads it as *"is my machine
> current?"* those are one question only while the source path is right — which is exactly what a
> copy cannot verify about itself.

⇒ this is why main's bundle phases pair every copy with a `cmp` in their verify half
(`term=asset`, `rule.require.upgrade-entries-verify-themselves`). the report is no longer the
evidence; the diff is.

## ⛔ .RETRACTED — the "two repos, one target" hazard

this cluster carried a second hazard, recorded 2026-09-07:

> *"`diff src/init.lua ~/.config/nvim/init.lua` ran to ~19,500 chars … keymaps whose own comments
> cite `grove.provision/4.terminal/4.3.kitty/…`. **another repo had become the author of that
> path.**"*

**that is false.** `src/grove.provision/4.terminal/4.3.kitty/` is a path in **this repo**, on
main. the 19,500-char diff measured one fact only: the branch it was run from was behind main.
there was never a second author.

⚠️ it is `gotcha.my-own-note-became-my-evidence`, in one hop: a misread of a path became a
measurement, the measurement became a hazard, and the hazard would have taught every later reader
to distrust a sync this repo fully owns. the tell was available and unread — **every citation in
the "other" file pointed at a directory this repo declares.**

⇒ the cheap check that would have caught it, before a diff is read as evidence of authorship:

```sh
rhx globsafe --pattern 'src/grove.provision/4.terminal/4.3.kitty/*'
```

a path that resolves inside this checkout is this repo's, whatever branch you happen to stand on.

## .the boundary — kept, because it records what beat the word

| word | what it implies | fits? |
|------|-----------------|-------|
| `sync` | a live copy re-derived from a declared source | ✗ **retired**: it names no direction, and this repo has two |
| **`grove.provision`** | converge a machine's extant tree to what the repo declares | ✅ the push half, and the chosen verb |
| **`git.repo.pull`** | update this repo from its remote | ✅ the pull half |
| `apply` | enact a plan | ✗ implies a diff was computed; a copy overwrites unconditionally |
| `deploy` | ship to a remote environment | ✗ the target is a machine this repo converges, never an environment |
| `copy` | move bytes | ✗ names the mechanism, and drops the direction |
| `update` | make newer | ✗ convergence also moves a config *backward* when the declaration does |

## .reason

see the ref-level file beside this choice:

- `term=sync._.choice.reason.md` — the stranded-fix incident in full, and the retraction's
  measurement
