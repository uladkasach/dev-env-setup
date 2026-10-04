# hazard: a converge from a stale branch moves the box BACKWARD

## .what

`rule.require.repo-as-source-of-truth` says the repo declares and the box follows. it holds, and it
carries one unstated premise: **the checkout you stand in is the newest revision of that
declaration.** a branch behind main breaks the premise, and `grove.provision --mode apply` obeys the
checkout either way.

so an apply from a stale branch is a correct convergence onto a superseded declaration. the box ends
up older than main, and every verify reports ✔ — because the box matches the tree it was told to
match.

## .why it is hard to see

a drift ✋ reports **difference**, never **direction**:

```
✋ ~/.zshrc does not match the checkout
   fix: rhx grove.provision --what 2.5.zsh --mode apply
```

that line is identical whether the tree is ahead of the box or behind it, and its fix-text is
correct in one of those two cases only. ⚠️ **a `diff` has the same property** — it names the lines,
and the reader supplies the direction.

⇒ and the fix-text is the trap, not the ✋. it is the one actionable sentence on the page, so a
reader who follows it on a stale branch takes the wrong action out of diligence.

## .the read that settles it — per HUNK, never per file

a branch is rarely wholly ahead or wholly behind. ask the diff against main, with zero context, and
read each hunk's own direction:

```sh
git diff -U0 origin/main -- <the artifact>
```

| the hunk | means |
|---|---|
| `+` carries your work, `-` carries main's older text | the tree is AHEAD — the apply delivers it |
| `-` carries main's work, `+` carries your older text | 🔴 the tree is BEHIND — the apply reverts the box |

⇒ **a file can hold both at once**, and that is the common case. a one-hunk regression beside a
dozen advances reads, on a `--stat`, as a file in conflict.

## .the repair — forward-port the hunk, never rebase for the apply

where the behind-hunks are few, take them from main into the branch and the tree is ahead on every
axis. the apply is then a pure forward move, and no rebase is owed.

```sh
git diff -U0 origin/main -- <artifact>    # name each behind-hunk
# edit the artifact: replace your older text with main's
rhx grove.provision --what <slug> --mode apply
```

✔ **measured 2026-09-30.** `2.5.zsh` sat 6 files and 44 lines apart from main. five files and five
of six `zshrc.sh` hunks were the tree ahead — the collocated-pointer cutover. **one hunk was
behind**, and it carried four `export CLAUDE_*` lines main had already deleted as a
`rule.forbid.two-writers-on-one-artifact` violation (`5.3.brains` declares those flags in
`settings.json` and is their sole writer).

⇒ the deferral it had earned read *"the apply is unsafe; a human must rebase first."* the per-hunk
read cut that to one edit, and `prove.rc-is-quiet-on-boot` went green the same hour.

## ⚠️ .what a behind-hunk often IS

a line main deleted **because a rule forbade it**. so a branch behind main does not merely carry
stale text — it can carry a live defect that main already repaired, and no clamp on the branch says
so, because the clamp was written before the repair.

⇒ so read a behind-hunk for *why main deleted it*, never only for *what it says*.

## .the test

> **before you apply, which side of this diff is newer — per hunk?**

- the tree, on every hunk → apply
- main, on any hunk → forward-port those hunks first, then apply
- you cannot tell → do not apply. the ✋ reports difference, and you need direction

## .enforcement

- a `grove.provision … --mode apply` run from a branch behind main, with no per-hunk direction read
  = **blocker**; it converges the box onto a superseded declaration and every verify reports ✔
- a drift ✋ answered by its own fix-text, with no check of which side is newer = **blocker**
- a deferral of an apply for "the branch is behind main", with no per-hunk read behind it =
  **blocker**; the behind-set is usually one hunk, and a forward-port retires the deferral

## .see also

- `rule.require.repo-as-source-of-truth` — the rule whose unstated premise this names
- `rule.require.upgrade-entries-verify-themselves` — why every verify still reports ✔ after a
  backward converge
- `rule.forbid.two-writers-on-one-artifact` — what the measured behind-hunk turned out to carry
- `term=sync._.choice._.md` — its retraction: a 19,500-char diff that measured one fact, that the
  branch was behind main
- `gotcha.a-check-that-cries-wolf-gets-silenced` — m.19, the clamp whose reader inherits the live
  copy of its subject, found the hour this apply landed
