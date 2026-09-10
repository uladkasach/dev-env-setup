# domain.term.choice.reason: sync — ⛔ RETIRED

⛔ the word is retired; see `term=sync._.choice._.md` for what replaced it. this file is kept for
the **measurements**, which are real and outlived the term they were written to justify.

## .etymology — and the property that survived the word

greek *sun-* (together) + *khronos* (time) — to draw into a shared time. the contraction carries
the one property that matters: **two things are made to agree, and one of them is the authority.**

that authority is what separated it from `copy`, and this repo still depends on it
(`rule.require.repo-as-source-of-truth`): the machine is downstream, always, and an edit made
there is expected to be lost.

⚠️ what killed the word was not the property. it was that **`sync` names no direction**, and this
repo has two — repo→machine and remote→repo. one word for both is the overload
`rule.forbid.domain-term-synonyms` forbids, so the human split it 2026-07-27 into
`grove.provision` and `git.repo.pull`.

## ✅ .the case that pinned the hazard

2026-09-03. an nvim leak fix — `neominimap` excluded from itself, plus a breaker that wipes the
leaked buffers — sat in a worktree for a full day. the alias read:

```sh
alias sync.devenv.nvim='... cp ~/git/more/dev-env-setup/src/init.lua ~/.config/nvim/init.lua ...'
```

a hardcoded source. the worktree held the fix; the main clone did not. so the correct advice
("run `sync.devenv.nvim`") was advice to copy the **old file over itself**, and it would have
printed `• neovim config synced` each time.

## ⚠️ .the hollow success — the durable lesson

> **an operation that reports on its own mechanism, rather than on its outcome, cannot fail
> visibly.** `cp` succeeded. the message was true. the machine was still wrong.

the report answered *"did a copy happen?"*. the human read *"is my machine current?"*. those
questions coincide only while the source path is correct — and the source path is the one input
the operation cannot check about itself, because it *is* the operation's own premise.

adjacent to `failhide` and distinct from it. a failhide swallows an error that occurred. here **no
error occurred**: every step did exactly what it was told. the defect is that the success was
reported at the wrong altitude — mechanism, not outcome.

it is also a `proxy`: "a copy completed" stood in for "the machine matches the source," with the
condition (a correct source path) unstated (`rule.require.name-what-you-measured`).

⇒ **main closed it structurally.** a bundle phase copies from `$GROVE_SRC` — which the driver
sets from the checkout it was invoked out of, so no constant is left to go stale — and its verify
half `cmp`s the live copy against that source. the report stopped serving as the evidence
(`term=asset`, `rule.require.judge-declared-state-not-live-state`).

## ⛔ .RETRACTED — the second hazard, and how a misread became a measurement

on 2026-09-07 this cluster gained a second hazard: *"a sync presumes it OWNS the target"*, on the
evidence that `~/.config/nvim/init.lua` carried keymaps whose comments cite
`grove.provision/4.terminal/4.3.kitty/…` — read as proof that **another repo** authored the file.

**it is false.** that directory is in THIS repo, on main. the ~19,500-char diff measured one
fact: the branch the diff was run from was behind main. no second author ever existed.

### what made it plausible, and what would have caught it

| the tell | why it went unread |
|---|---|
| the cited path resolves inside this checkout | the reader stood on a branch that predates the directory, so a list of it came back empty and read as "not ours" |
| the diff was huge | a large diff was taken as evidence of a DIFFERENT AUTHOR, where it is only evidence of DISTANCE |

⇒ the check is one command, and it is cheap:

```sh
rhx globsafe --pattern 'src/grove.provision/4.terminal/4.3.kitty/*'
```

an empty result on YOUR branch says where your branch is. it says none of what the repo declares.

### why it is recorded rather than deleted

`gotcha.my-own-note-became-my-evidence` names this exactly: a claim written down becomes the
evidence for itself, and by the second hop it reads as repo-attested. the hop count here was
**one**, and the hazard was already shaped into a rule (*"diff the target before any sync"*) that
would have taught later readers to distrust a path this repo fully owns.

> **a large diff against a live config is a measurement of DISTANCE, never of AUTHORSHIP.** the
> two are told apart by a read of the repo, never by the size of the diff.

## .the neighbours

- **`grove.provision`** — the push half, and the chosen verb
- **`git.repo.pull`** — the pull half
- **`asset`** — the mechanism that retired the hollow-success hazard: a second copy to `cmp`
- **`proxy`** — the success message proxied for delivery. still the shape of the defect
- **`amplifier`** — how the hazard compounds: an undelivered fix means the leak keeps its growth,
  which slows the box, which makes the next diagnosis harder
