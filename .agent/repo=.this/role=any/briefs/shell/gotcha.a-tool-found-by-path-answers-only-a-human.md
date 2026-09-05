# gotcha: a tool found by PATH answers a human and vanishes for everyone else

## .what

this repo puts most of its tools on PATH from `~/.zshrc`. zsh sources that file for an
**interactive** shell only. so any component that finds its dependency **by name** works
perfectly at a human's keyboard and is absent for every other caller.

measured on `grove-ahbode-v20260810`, camper seat, 2026-08-11:

| caller | shell it gets | files it reads | tool found? |
|---|---|---|---|
| a human's terminal | interactive login | `.zshenv` + `.zshrc` | ✔ |
| `ssh grove '<cmd>'` | `bash -c` (see ⚠️) | **none** | ✋ |
| a cron, a systemd unit | `sh -c` | none | ✋ |
| a jest suite spawned by automation | inherits its parent's | whatever that carried | ✋ |

```
$ getent passwd camper
camper:x:1002:1002::/home/camper:/bin/bash        ← the login-shell RECORD

$ ssh camper 'echo $PATH'
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/games:…
```

the tool is installed, executable, current, and one directory away. it is simply unnamed
in that shell.

## ⚠️ .why row 2 reads NONE and not `.zshenv`

two facts settle it:

1. **`ssh host '<cmd>'` runs the login-shell RECORD, not zsh.** the camper's record is
   `/bin/bash`, so ssh runs `bash -c '<cmd>'` — zsh is never invoked, so no zsh file is
   ever a candidate. `.zshenv` applies only on a seat whose record IS zsh.
2. **a non-interactive, non-login bash reads `$BASH_ENV` and no other file** — not
   `.bashrc`, not `.profile`, not `.bash_profile`. `$BASH_ENV` is unset here.

⇒ the row is not "fewer files", it is **zero files**. 🛑 a fix placed in `.zshenv` looks
like it should serve ssh and does not.

⚠️ **and the seat's record is itself a defect, not a given.** `2.5.zsh` runs
`sudo chsh -s "$(command -v zsh)" "$USER"`, so on this box:

```
ground:  …:/usr/bin/zsh    ← the seat WITH sudo — record written
camper:  …:/bin/bash       ← the seat without  — record refused
```

same box, same pam. the bundle's decline blames *"pam refuses it for a password-less
user"*; ground disproves that in one line. the real cause is **privilege on that seat**,
and the camper — the seat that does the work — is the one that cannot write its own record.
see `term=decline._.choice.reason.md` for why a wrong reason inside a `🌙` is the hardest
kind to catch.

## .why it is worse than an absent tool

an absent tool fails the same way every time, so the first person to hit it fixes it.

this one **fails by caller**, which means:

1. the human tests it by hand and it works
2. the automation fails
3. the error names the SYMPTOM, never the PATH

git is the clearest case: it never says *"the helper is not on PATH"*. it says
`could not read Username`. so the visible fact is an auth failure and the cause is a
shell startup file, with no link between them a reader could follow.

## .measurement — four rungs of one chain, 2026-08-10

`git ls-remote https://github.com/<org>/<repo>` on a converged grove, over ssh. each fix
uncovered the next rung, and every rung was the same defect:

| # | what was named by PATH | what it printed | fix |
|---|---|---|---|
| 1 | `git-credential-keyrack` — git found the helper via `helper = keyrack` | `could not read Username` | the config names the ABSOLUTE path |
| 2 | `rhx` — the helper's own reader | `rhx absent — declines` | the helper supplies `$PNPM_HOME` |
| 3 | `node` — `rhx` is a `#!/usr/bin/env node` shim | `env: 'node': No such file or directory` | the helper supplies fnm's `aliases/default/bin` |
| 4 | *(one layer out)* `rhx` inside `git.grove.send --play`, which sent `bash -l` | every `rhx` line exited 127 | the send probes the seat and uses `zsh -ic` |

⚠️ rung 3 is the one that hides best: `rhx` was **found** and could not **run**, and from
git's side a shim that cannot run is indistinguishable from one that is absent — both end
as one empty token.

⚠️ and rung 1 shipped a **verify that measured the wrong box**. it ran
`command -v git-credential-keyrack`, which reads the PATH of whatever shell ran the
VERIFY, never the PATH of the shell that will run GIT. it reported ✋ over the duct and ✔
from a human's terminal, on one box, in the same minute — a verdict about the caller,
dressed as a verdict about the box.

## .the rule

> a component exec'd by something other than a human's shell must name its dependency
> **directly**, never by PATH.

| the dependency is reached by… | then… |
|---|---|
| a human, at a prompt | PATH is fine — that is what an rc is for |
| a program (git, cron, a suite, ssh) | name the path, or supply the dir at the point of use |

⚠️ and where a shell variable IS the right answer, `~/.zshenv` is the right file — read by
every zsh, interactive or not — which is the lesson `AWS_PROFILE` taught on 2026-08-06 and
the reason `src/zshenv.sh` exists.

**but `.zshenv` is not a substitute for the rule above.** it reaches every ZSH; it reaches
no bash, no `sh -c`, and no seat whose login-shell record is not zsh. so it serves a duct
send (which execs `zsh -ic`) and serves no bare `ssh host '<cmd>'` on a bash-record seat.
a dependency a PROGRAM must find still gets named directly, whatever `.zshenv` holds.

## .why NOT to fix it by five more PATH declarations

the tempting repair is to add the dir to `.zshrc`, `.zshenv`, `.profile`,
`.bash_profile`, and whatever a cron reads. that is **five declarations of one fact**,
each able to drift — the two-lists defect this repo keeps re-learning
(`rule.require.identical-bundle-composition`). one absolute path, or one dir supplied at
the point of use, is a single declaration every caller obeys whatever shell it was born in.

## .the test

before you trust that a tool is reachable:

> **who execs it — a human's shell, or a program?**

if a program, ask the box the way that program will:

```sh
rhx git.grove.send <grove> --bare --why 'this probe needs a NON-INTERACTIVE shell' \
  --what '<the exact command the program runs>'
```

a `--bare` send is a non-interactive shell, so it reproduces the automation's PATH rather
than the human's. that one command is what turned four invisible rungs into four named ones.

⚠️ **this is the one place `--bare` survived the 2026-08-13 sweep, and the `--why` is why.**
`--reply` is the wrong tool HERE, and not by a little. a duct is tmux; its pane runs an
**interactive** zsh. so `--reply` reproduces the human's PATH — the exact condition this
probe exists to escape. the trigger is the SHELL, never the verdict.

⇒ this site once carried the repo's most-typed `--why` (*"a verify needs the remote
verdict"*), so a stale trigger hid a live one. an exemption that names the wrong trigger
looks identical to one that names the right trigger, right up until the wrong one is retired
and the site is "cleaned up" into uselessness (`rule.require.exemptions-name-their-trigger`,
`rule.forbid.exemption-as-habit`).

## .see also

- `gotcha.the-duct-returns-the-send-not-the-answer` — why the probe must be `--bare`
- `gotcha.a-check-that-cries-wolf-gets-silenced` — rung 1's verify is a worked example of
  a check whose verdict was about its own caller
- `gotcha.bash-lc-becomes-a-half-zsh` — the shell seam this rests on
- `src/zshenv.sh` — the file for env a PROGRAM must read
- `src/git-credential-keyrack.sh` — carries rungs 2 and 3 inline
