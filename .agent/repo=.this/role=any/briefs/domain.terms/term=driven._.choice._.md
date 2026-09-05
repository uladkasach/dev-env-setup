# domain.term: driven

term.chosen   = driven
term.kind     = adj
term.synonyms.forbidden:
- source       (says "under `src/`", which both over- and under-reaches: `bash_aliases.sh` is
                under src and is NOT driven, and `grove.bootstrap.sh` is outside it and IS)
- prodcode     (a test-framework split. this repo has no test/prod halves; it has a runtime and
                a keyboard, which is a different cut entirely)
- internal     (names who WROTE it. every file here is internal; the question is who CALLS it)
- tracked      (git's word, and git tracks the human's aliases too)
- scanned      (names the READER's act. driven is a property of the subject, true before any
                play was written and true of files no play reads)
- executable   (a file mode. a human-typed alias is executable and is not driven)

## .what
a file is **driven** when this repo's runtime, or another PROGRAM, executes it with no human at
the keyboard.

the set:

| member | who executes it |
|---|---|
| `src/grove.provision/**` | `bundle.upgrade`, at every depth |
| `src/grove.*.sh`, `src/bundle.upgrade.sh` | the entrypoint sources them |
| `grove.bootstrap.sh` | the readme, before the repo exists |
| `src/git-credential-keyrack.sh` | **git**, on every fetch |

## 🛑 .the DIRECTORY does not decide membership — the CALLER does
`src/` holds both halves, side by side. `git-credential-keyrack.sh` and `bash_aliases.sh` are
one directory apart, and only the first is driven — because git invokes one and a human types
the other.

⇒ so a sweep scoped by PATH is a claim about the wrong axis. read who calls the file.

## .its opposite — the INSTALLED ARTIFACT
`bash_aliases.sh`, `ductwork.sh`, `termwork.sh`, `zshrc.sh` are copied ONTO a box and invoked by
a human at a prompt. they are not driven, and the distinction is not cosmetic: **the same demand
is correct on one side and a REGRESSION on the other.**

measured twice on 2026-08-15, in two plays written hours apart:

| the demand | on a DRIVEN call | on a human's alias |
|---|---|---|
| `GIT_TERMINAL_PROMPT=0` | required — a prompt on a headless box wedges the duct forever | a regression — a prompt is the CORRECT affordance for a human who must authenticate |
| `env -C "$root"` on a keyrack read | required — an inherited cwd renders a throw as `absent 🫧` | a regression — the cwd IS the input; a human means to read the repo they stand in |

⇒ a reader that swept both halves would print a plausible, specific, and harmful `fix:` for
every row in the second column (`gotcha.a-check-that-cries-wolf-gets-silenced`, m.7).

## .what a driven file may NOT assume
it is the whole point of the word. a driven file runs with:
- no tty a human watches, so no prompt can be answered
- no cwd it chose, so no ambient state is its input
- no shell rc read, so no PATH it did not name
  (`gotcha.a-tool-found-by-path-answers-only-a-human`)

## .refs
where the term is declared / used — ⚠️ no COUNT here: the set is discovered from the tree, and
a count in a brief is a second declaration that decays with no signal (`repo.overview.md`).
- src/git-credential-keyrack.sh                             # driven, and it sits in `src/`
- .agent/repo=.this/role=any/briefs/grove/provision/define.provision-defect-shapes.md  # `.the NINTH shape`

## .reason
see the ref-level cluster beside this choice:
- `term=driven._.choice.reason.md` — etymology, the synonyms declined, and the measurement
  that made the boundary load-bear
