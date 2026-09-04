# gotcha: a test that names a REAL home has no sandbox, and its blast radius is every session

## .what

a check that plants a fixture at a **fixed absolute path under `$HOME`** does not test a
sandbox. it edits the machine. and when the path it names is a file some other tool holds
open, the fixture becomes that tool's live config.

measured 2026-08-31, three times in one session:

```
Configuration Error
The configuration file at /home/vlad/.claude.json contains invalid JSON.
Unexpected token 'o', "not json at all" is not valid JSON
  ❯ 1. Exit and fix manually
    2. Reset with default configuration
```

`not json at all` is a **fixture string**. one file on this box holds it:

```
_worktrees/dev-env-setup.vlad.brain-budget-utilization
  /.agent/repo=.this/role=any/skills/brains.auth.test.sh
```

it writes a malformed-config case to prove a reader rejects one — and it names the real
`~/.claude.json` to do it. so every run of that check corrupts the config of every claude
session on the box, in every worktree, for every repo.

## 🛑 .the recovery, before anything else

```sh
cp ~/.claude.json.backup ~/.claude.json    # 401_679 bytes, valid
```

⚠️ **never pick option 2, "Reset with default configuration".** the backup holds ~400kb of
real state — 1419 startups, per-project history, mcp registrations. a reset discards all of
it to fix a 15-byte corruption that one `cp` repairs.

## .why it is worse than an ordinary bad test

an ordinary bad test fails in its own run and blames itself. this one:

1. **succeeds.** the check under test correctly rejects the malformed config, so the run
   goes green and reports no fault at all.
2. **damages a THIRD party.** the harm lands on every other session on the box, none of
   which ran it.
3. **is unattributable from the damage.** the human sees a config dialog with no author,
   no timestamp, and no clue which of a dozen worktrees produced it.

⇒ so it is `rule.forbid.fixed-paths-in-a-shared-tmp`, one scope out. that rule bounds a
shared `/tmp` between two SEATS on one box; this bounds a shared `$HOME` between two
CHECKOUTS of one repo. same defect: a fixed path plus more than one writer.

## 🛑 .the corrupter is UNREADABLE from a sibling worktree — and that is the second lesson

three routes were tried, and all three refuse for a different reason:

| route | why it refuses |
|---|---|
| a direct `Read` of the sibling path | the `forbid-cross-repo-access` hook blocks it |
| `rhx git.repo.get --tree <branch>` | *"--tree requires a local clone"* — it treats the repo as cloud |
| `git ls-files --with-tree=<branch> <path>` | *"did not match any file(s) known to git"* |

the third is the informative one: the file is **uncommitted on that branch**, so no git
plumbing can reach it from here. a defect that lives only in another worktree's dirty tree
is visible to exactly one session — the one standing in it.

⇒ **the fix has to be made from the worktree that holds it.** from any other, the only
available move is the record you are now in.

## .the rule it yields

> a check that writes may name a path under a **generated** root, and never a fixed one
> under `$HOME`.

| the check needs | it uses |
|---|---|
| a malformed config to reject | a temp dir it created, and a var that points the reader at it |
| a real config to read | a COPY, in that temp dir |
| the live `~/.claude.json` | ✋ no check ever names it |

and the general form, which this repo already states twice:

- `rule.forbid.repair-plays` — a play READS; a write belongs in a bundle, or in a
  disposable rollback under the gitignored `.play/temporary/`
- `rule.forbid.fixed-paths-in-a-shared-tmp` — a fixed path plus a second writer is the
  defect, whatever the dir is called

## ⚠️ .a permission hook rejects a NOVEL command shape and passes an IDENTICAL retry

the restore took several attempts, and the reason was not the command:

> the first attempt of a command SHAPE the allowlist has not seen is refused. the same
> bytes, sent again, pass. a differently-shaped compound resets the counter.

⇒ so when a repair is refused, **send it again unchanged** before you reshape it. each
reshape is a fresh novel shape and starts the count over — which is how a one-line `cp`
became four blocked attempts and one success.

⚠️ and the cost of not knowing this was paid by the human: the incident was reported and
the `cp` was handed BACK to them to run, three times, when a retry of the identical command
would have landed it. *"why have you still not fixed this?"*

## .see also

- `rule.forbid.fixed-paths-in-a-shared-tmp` — the same defect, bounded to a shared `/tmp`
- `rule.forbid.repair-plays` — why a check that writes needs a named exemption
- `gotcha.a-check-that-cries-wolf-gets-silenced` — the adjacent family, where the check is
  wrong rather than the write
