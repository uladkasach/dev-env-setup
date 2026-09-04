# rule.require.name-a-skill-by-who-invokes-it

## .what

when you name a skill, or choose the family it joins, ask **who invokes it** — never what it
reads.

a **gate** is run by the repo, at you. a **tool** is run by you, at your own work. the two read
identical bytes and belong in different families.

## .why

a skill's subject is the loudest fact about it, so it is the axis a writer reaches for first —
and it is the wrong one. two skills can walk the same tree, parse the same files, and print the
same shape of verdict while one blocks a merge and the other sits beside your keyboard.

name by subject and the tool lands in the gate's family, where it inherits a gate's ergonomics
(`--mode`, `--scope`), a gate's cadence, and a gate's reader expectations — none of which it
wants.

## .the test

> **who types this — the repo, or me?**

| | a GATE | a TOOL |
|---|---|---|
| who runs it | the repo, at you | you, at your own work |
| when | on a commit, a push, a release | mid-edit, to check yourself |
| what a red means | stop, the change cannot land | look again, you are mid-thought |
| named as | a member of the gate family | its own verb |

## .measured — 2026-08-31, and the wrong axis was mine

`shell.syntax.verify` reads `.sh` files off a disk and runs `bash -n` on each. it drives no live
surface — no keyboard to send to, no window to read.

from that I concluded it was a **repo gate**, the same shape as
`git.repo.test --what types|format|lint`, and proposed it ship as `git.repo.test --what shell`.
the argument was sound about the subject and silent about the caller.

the human's read:

> *"defo not a `--what shell`, its just a compiler or linter. but a valid skill for the mechanic
> to check their work with"*

⚠️ **a compiler is the case that settles it.** `tsc` reads files and reports errors, exactly as a
lint gate does. nobody calls it a gate, because a human runs it mid-edit, dozens of times, and a
red means *carry on*. the cadence differs and so does what a failure SAYS — and neither is
visible from what it reads.

## .the corollary

a skill that is genuinely both gets **two names**: the tool keeps its own verb, and the gate
calls it. do not collapse them into one flag on the gate — that makes the tool reachable only
through the very command that runs it at you.

## .enforcement

- a skill placed in a family by its SUBJECT, with no account of who invokes it = **nitpick**
- a mechanic's TOOL shipped as a flag on a repo GATE = **blocker**; it is then reachable only
  through the gate, at the gate's cadence

## .see also

- `rule.require.wrap-cli-in-skills` — why the ad-hoc form is wrong every time it is retyped
- `rule.require.bundle-names-name-their-subject` — the twin rule for BUNDLES, where the subject
  IS the right axis, because a bundle has exactly one caller
- `gotcha.my-own-note-became-my-evidence` — the adjacent trap: a well-argued case whose ground
  was never checked against the one who would run it
