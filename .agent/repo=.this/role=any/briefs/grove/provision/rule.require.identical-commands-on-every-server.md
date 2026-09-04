# rule.require.identical-commands-on-every-server

## .what

a command a human runs on a laptop must run **byte-identically** on a grove.

```sh
cd <repo> && rhx git.repo.test --what integration
```

that exact line. no wrapper, no prefix, no extra export, no cloud-only variant. if the
laptop needs none of those, the grove needs none of those.

when the grove needs more, the extra is a **defect in the box's provision** — never a
different command. fix the bundle; keep the command.

## .why

- a grove exists so work can happen on it. work means the commands the human already knows
- a cloud-only invocation is a second, unrecorded way to drive the same repo — the exact
  second-path habit `rule.require.repo-as-source-of-truth` kills everywhere else
- the wrapper hides the gap it fills. once `sg docker -c …` is in a play, nobody learns that
  the box's group grant never took effect, and the next command that needs docker fails for
  a reason the last one already papered over
- muscle memory is a real interface. a human who must remember "on the grove, prefix it" is
  a human who will forget, and then read a stale env's failure as a code failure

## ⚠️ .the measurement — 2026-08-06, svc-chat on grove-1

the integration suite ran **0 of 19 suites**. wrapped, it ran 31 tests:

```sh
sg docker -c "zsh /tmp/run.suite.zsh '$TREE'"      # 9 passed, 22 failed
rhx git.repo.test --what integration --thorough    # 0 passed, 0 failed
```

that pair is the whole rule. the wrapper was a **true statement about the box** and a
**false statement about the command**:

| the wrapper supplied | what a laptop already had | so it concealed |
|---|---|---|
| `sg docker -c` | the docker group, from a login AFTER install | that the live session never picked the group up |
| `zsh …` | an rc/env read that a login shell does anyway | that the env sat in a file the test's shell never opened |

each half was a real, locatable provision gap:

- `AWS_PROFILE=ambient` was declared in `~/.zshrc`. zsh reads an rc for **interactive**
  shells only, and jest is not one — so it moved to `~/.zshenv`, which every zsh reads
- the `docker` group applies at **next login**, and a duct is a tmux session that predates
  the install — so `duct.reboot` is how a live pane picks it up, and `5.8.docker`'s verify
  now re-asks under `sg` rather than pass on a permission denial

with both fixed at the box, the bare command is the one that has to go green.

## .how — when a cloud run needs an extra

1. **name what the laptop supplies for free.** a group membership, an env var, a file, a
   daemon, a credential
2. **find the bundle that owns it**, and make that bundle supply it on a grove too
3. **make its verify prove the human's path**, not a wrapped one — a probe that asks a
   shell no program will run answers about a shell that does not matter
4. **delete the wrapper.** it was the diagnosis, and a diagnosis left in place becomes a
   requirement nobody remembers having chosen

## .the tell

before you accept a cloud run as green, ask: **could the human have typed this on their
laptop, character for character?**

- yes → the run proves the command
- no → the run proves the wrapper, and the box is still broken

## .what this does NOT forbid

- a **diagnostic** wrapper, while the gap is still unlocated. `sg docker -c 'docker info'`
  in a verify is legitimate precisely because it asks *"would a fresh login work?"* — a
  question, not a workaround
- a **`--for`/mode flag the command itself declares** (`grove.provision --for cloud`). that is
  one command with an argument, not two commands
- a genuinely cloud-only OPERATION (`git.grove.wake`). the rule is about a command that
  exists on both, invoked differently

## .enforcement

- a cloud-only wrapper, prefix, or export around a command that runs bare on a laptop =
  **blocker**
- a play or proof that reports green on a wrapped invocation of a command the human runs
  bare = **blocker** (it proves the play, not the box)
- a provision gap found by a wrapper and left with the wrapper in place = **blocker**

## .see also

- `rule.require.prove-the-path-the-human-runs` — the same principle, aimed at proofs
- `rule.require.identical-bundle-composition` — one tree, every server
- `rule.require.install-via-procedures` — never hand a human a one-off
- `rule.require.repo-as-source-of-truth` — why an unrecorded second path is the defect
- `rule.require.prove-changes-on-a-grove` — and why a laptop cannot answer this alone
- `domain.terms/term=probe._.choice.reason.md` — the sixth hazard: a probe that asks a
  shell no program will run
