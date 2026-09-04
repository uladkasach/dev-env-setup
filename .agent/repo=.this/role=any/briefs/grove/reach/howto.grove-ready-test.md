# howto: the grove-ready test

## .what

**the grove-ready test** is the one question that decides whether a grove can do work:

> is this BOX in a state where a suite could be run on it?

it is a **ladder of five rungs**. each is a state the box must hold before the next can
be true. one skill climbs it and HALTS at the first rung that does not hold:

```sh
rhx git.grove.ready.verify <name>
rhx git.grove.ready.verify <name> --from 4          # resume at rung 4
rhx git.grove.ready.verify <name> --from 4 --upto 4 # re-check just rung 4
```

| rung | holds when | the fix when it does not |
|---|---|---|
| 1 registry | an entry names the grove, with an exid and an account | `git.grove.set` |
| 2 reach | the box wakes and the account assertion passes | `keyrack unlock`, then `git.grove.wake` |
| 3 duct | tmux is on the box, so a duct can hold | apply `2.8.tmux` bare |
| 4 devenv | the checkout is there AND every bundle verify passes | push `src/`, then apply detached |
| 5 creds | gh is authed and aws names an identity | apply `5.4.gh` / `5.6.aws` |

exit `0` = ready · `3` = a rung named its failure and its fix · `2` = bad input ·
`1` = malfunction.

## 🛑 .the subject is the BOX — the tree is a different question

every rung asks about the MACHINE. not one asks about a repo checked out on it, and that
boundary is deliberate.

📜 measured: a `6 tree` rung (is the target repo cloned, with its deps) and a `7 suite` rung
(does the integration suite tally green) once sat here. they were **synonyms** of
`git.grove.provision test` steps 1, 2, and 4 — one set with two readers, free to disagree
(`gotcha.a-check-that-cries-wolf-gets-silenced` m.9). rung 7 ran `--mode apply` against a
live testdb, which refuted this ladder's own read-only guarantee.

⇒ 🛑 **do not add a rung about a tree.** it re-earns both defects at once.

⇒ for a question about a repo on the box, reach for the command that can ACT on the answer:

```sh
rhx git.grove.provision test <name>
```

⚠️ a read-only ladder may not judge a precondition its caller is about to ESTABLISH — it
would halt on the very state that caller exists to create. that is the durable reason there
is no rung 6, and it is why a re-added one would break the caller rather than help it.

## .why a ladder, and why it HALTS

"provision a grove" is not one act, it is a chain — and a chain reports its breaks badly.
a fresh box fails rung 5 **because** it failed rung 2, and a report that names all five
names ONE root cause five times over.

that is exactly the shape `prove.phase-chain-breaks` was written to forbid: when a phase
fails, the rest must stand down rather than restate it. so the first broken rung is the
whole answer, and its fix is the whole next move.

⚠️ the halt is also what makes the loop cheap. a driver reads one rung, runs one fix, and
re-climbs from there — it never re-proves what already held.

## .why verify, and not test

`test` is spoken for: `git.repo.test` **runs suites**. this reads state and asserts a
verdict about it, which is what `verify` names (`term=play.verify`). no rung runs a suite —
that is `git.grove.provision test`'s step 4.

the skill **writes no state of its own**. rung 2 wakes the box, which is idempotent
and free (`rule.require.wake-the-grove-freely`); every other rung is a read. it never
installs, never clones, never repairs — it names the repair to run.

⚠️ that guarantee was FALSE while rung 7 existed — the file asserted it anyway. a
`.safety` claim is worth exactly as much as a re-read of the rungs beneath it
(`rule.require.trust-but-verify`).

## ⚠️ .the trap this ladder was built on top of

each rung asks the box a question, and the obvious way to ask is the wrong one.
`git.grove.send --what '<cmd>'` returns the SEND's exit code, which is `0` whenever the text
landed — so a rung that judges it judges the delivery, never the command. this ladder's own
first climb printed **three false ✔** on a box that held no checkout at all.

⇒ every rung asks with `--reply`, through the skill's `_ask` helper, and **halts on exit 97**
rather than judge a box that never spoke.

the full measurement lives in `gotcha.the-duct-returns-the-send-not-the-answer.md`.

## .the loop

the ladder is a single climb. to drive a box all the way to ready, wrap it:

1. climb — `rhx git.grove.ready.verify <name>`
2. exit 0 → the box is ready. for the tree and the suite, run
   `rhx git.grove.provision test <name>`.
3. exit 3 → it named ONE rung and its fix. run the fix. a long fix (a devenv apply, a
   pnpm install) goes `--detach`, and the NEXT climb reads its result rather than a
   blocked wait here.
4. climb again from that rung.

⚠️ **a wall deserves a stop, not another lap.** if the same rung fails three climbs with
the same cause, hand the human the blocker with what was tried. a loop that grinds on an
unmovable rung burns the box and teaches nobody.

## .how to read each halt

every halt prints `why`, a `fix`, and a resume hint. one is worth extra care:

**rung 4** asks two separate questions, because they take opposite repairs and both look
like "0 ✔":
- no checkout → push `src/` (the box has the repo it needs to converge itself)
- checkout present, verifies claim → apply, detached

⚠️ push the **worktree**, not a clone from main. a clone can only run what is merged, so
it cannot prove an unmerged branch. and `--into` takes a **remote-home-relative** path — a
`~` at the front expands on YOUR machine, and the grove's user is its own.

## .the logs

each rung keeps its raw output under
`${XDG_STATE_HOME:-~/.local/state}/grove.ready/<grove>/`, one file per rung. they are KEPT
rather than discarded, so a halt leaves evidence a human can read instead of a verdict they
must take on faith.

⚠️ NOT `/tmp` — this repo forbids a bash read or write there, because /tmp is not
temporary: it persists, never auto-cleans, and a log left there outlives every memory of
why it was written.

## .see also

- `gotcha.the-duct-returns-the-send-not-the-answer.md` — the trap every rung is shaped by
- `howto.adopt-a-replacement-grove.md` — the stale entry rung 1 exists to catch
- `howto.bootstrap-a-grove-from-scratch.md` — the long form of rung 4's first fix
- `rule.require.prove-changes-on-a-grove.md` — why a laptop cannot answer this question
- `rule.forbid.failhide` — why rung 4 judges a tally rather than an exit code
- `.agent/repo=.this/role=any/skills/git.grove.provision.test.sh` — the tree and suite
  questions this ladder no longer asks, held by the command that can act on them
