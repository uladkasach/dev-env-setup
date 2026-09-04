# gotcha: `bash -lc` on a converged box is a HALF zsh, and it blames the wrong cause

## .what

a probe sent to a grove as `bash -lc '<cmd>'` does not run bash. `2.5.zsh` declares a
hand-off in `~/.bash_profile`, so a bash LOGIN shell execs zsh — and because `-c` makes
that zsh non-interactive, it loads `~/.zshenv` and **skips `~/.zshrc`**.

that is half a shell, and the half it drops is not the half you would guess.

## .the two halves, and why they live in different files

| file | carries | loads in |
|---|---|---|
| `~/.zshenv` | `AWS_SDK_LOAD_CONFIG=1` | **every** zsh — interactive or not |
| `~/.zshrc` | pnpm's global bin on `PATH` | interactive only |

the split is deliberate and correct. `2.5.zsh`'s own comment says `.zshenv` carries
`AWS_SDK_LOAD_CONFIG=1` precisely because "a program genuinely must read" it, whether or
not a human is present. `PATH` for an interactive toolchain is a `.zshrc` concern.

so three transports give three different environments for one command:

```
bash -lc  → .zshenv ✔   .zshrc ✗   → rhx: command not found
zsh -lc   → .zshenv ✔   .zshrc ✗   → rhx: command not found
zsh -ic   → .zshenv ✔   .zshrc ✔   → works
```

⚠️ **`bash -lc` resolves differently before and after `2.5.zsh` runs.** on a fresh seat it
really is bash, and it finds `rhx` through `~/.bash_aliases`. the moment that bundle lands,
the same string denotes a different shell. a transport that shifts under a convergence is
the worst kind of harness.

## .measurement — a login shell that reported itself as a region, 2026-08-10

svc-chat's integration suite, run over a duct as `bash -lc`:

```
ConfigError: Missing region in config
  at invokeLambdaFunction(...)
```

19 suites, 22 failures, every one of them against a region. the box had:

- `~/.aws/config` with `region = us-east-1` in the profile ✔
- a rack entry that named that profile ✔
- a proven assume-role hop into the right account ✔

all three were correct. aws-sdk **v2** does not read `~/.aws/config` at all unless
`AWS_SDK_LOAD_CONFIG=1` is set — and that variable lives in `~/.zshenv`, which the
transport had skipped.

⇒ the error named the LAST fact the sdk lacked, and the cause was the shell that started
it. two full runs were spent on aws before the transport was suspected.

the fix was a two-character change to the harness, and it moved the tally from
`9 passed / 22 failed` to `25 passed / 6 failed`.

## .why this is `rule.require.prove-the-path-the-human-runs` exactly

a duct is tmux, and tmux runs an **interactive** zsh. so:

> a probe on `bash -lc` proves a path no human on this box ever walks.

it is the same defect as a laptop run as a stand-in for a grove run — a proof about an
environment that is not the one in question. ⚠️ `--bare` is the opposite trade: it returns a
verdict and costs you the duct's interactive shell
(`gotcha.the-duct-returns-the-send-not-the-answer`).

## .the shape to reach for

```sh
# 👎 a half zsh, and it denotes a different shell once 2.5.zsh lands
rhx git.grove.send <g> --reply --what "env -C <dir> bash -lc '<cmd>'"

# 👍 the shell a duct actually gives a human
rhx git.grove.send <g> --reply --what "env -C <dir> zsh -ic '<cmd>'"
```

⚠️ `zsh -ic` on a pipe prints the prompt's own noise into your capture. that is a cosmetic
cost, and it is the correct trade: a clean capture of the wrong environment is worth less
than a noisy capture of the right one.

## .the test

before you trust a failure that came back over a duct:

> **would this command have failed the same way in a duct pane?**

if the probe used `bash -lc` or `zsh -lc` and the error names a config file, an absent
binary, or an unset variable — suspect the shell before the subject. re-run under
`zsh -ic` and compare. a difference IS the answer.

## .the open question this leaves

`rhx` is on `PATH` only for an interactive shell, so **no non-interactive automation on
this box can invoke it** — a cron entry, a systemd unit, a `ssh <host> '<cmd>'`. that is a
real constraint and it is not obviously right. whether pnpm's bin belongs in `~/.zshenv`
beside its neighbour is a question for a session that can measure the blast radius; it is
recorded here rather than answered.

## .see also

- `rule.require.prove-the-path-the-human-runs` — the rule this is an instance of
- `gotcha.the-duct-returns-the-send-not-the-answer` — the other half of the transport seam
- `src/grove.provision/2.shell/2.5.zsh/configure.upsert.sh` — the owner of both files
- `src/zshenv.sh` — where `AWS_SDK_LOAD_CONFIG=1` is declared
