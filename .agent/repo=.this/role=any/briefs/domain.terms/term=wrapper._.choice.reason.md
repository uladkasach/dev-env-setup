# domain.term.choice.reason: wrapper

## .etymology

`wrapper` is borrowed from its plain english sense — *a thing put AROUND another thing*.
what is inside is unchanged; what reaches it is not. that is exactly the shape:
`sg docker -c 'docker info'` runs `docker info` untouched, and changes what it arrives
holding.

the word also carries the right connotation for free: a wrapper is **removable**. you
unwrap a thing and it is still the thing. that is precisely the claim this term needs a
reader to feel — a wrapper is never the artifact, it is a layer around one, and the
question is always whether it should still be there.

## .the measurement that forced the word — 2026-08-06

svc-chat's integration suite on grove-1, one command, two invocations:

```
sg docker -c "zsh /tmp/run.suite.zsh '$TREE'"       → 19 suites,  9 passed, 22 failed
rhx git.repo.test --what integration --thorough     → 19 suites,  0 passed,  0 failed
```

the wrapped run looked like enormous progress: 0 → 31 tests. it was **a true statement
about the box and a false one about the command.** each layer supplied what a laptop
supplies for free, and by that supply concealed the gap:

| layer | what a laptop already had | what it concealed |
|---|---|---|
| `sg docker -c` | the docker group, from a login AFTER the install | the live duct session never picked the group up |
| `zsh …` | an rc/env read a login shell does anyway | `AWS_PROFILE` sat in `~/.zshrc`, which only INTERACTIVE shells read — and jest is not one |

the human's response is the term's other half: *"why do you need a custom zsh runsuite"*,
*"it needs to work the same way it works locally"*, *"git.repo.test should work out of
the box — that's your objective"*. once both gaps were closed at the BOX (`~/.zshenv` for
the env, `duct.reboot` for the group), the bare command returned the identical tally.

⇒ the vocabulary had no way to say what was wrong with that first run. it was not a
"hack" (it was principled), not a "workaround" (it diagnosed correctly), and not a
`shim` (a shim adds no behavior). it was a **wrapper**, and the defect was not that it
existed but that it was KEPT.

> a wrapper is a fine instrument and a terrible resting place.

## .the pair it completes

`wrapper` sits opposite `shim` on the does-it-add-behavior axis:

| | `shim` | `wrapper` |
|---|---|---|
| adds behavior | none — it only redirects | yes — a group, an env, a shell |
| what it says about the box | that a concern is reached from two paths | that the box lacks what the command needs |
| lifetime | permanent, by design | temporary, or probe-internal only |
| deletion | loses a convenience path | loses the concealment, exposes the gap |

a file that transforms args or adds a retry is already excluded from `shim`
(`term=shim`, `.the test`) — this term is where those land, and it says what to DO about
one rather than merely that it is not a shim.

## .why each forbidden synonym is forbidden

- **`shim`** — the direct counterpart, and the confusion that costs most. a shim is
  legitimate forever; a wrapper is a gap frozen in place. to call one the other is to
  inherit the wrong lifetime, and a wrapper that reads as a shim never gets deleted.
- **`workaround`** — names a VERDICT, not a shape, and prejudges. a wrapper is the
  correct first move when the gap is unlocated: `sg docker -c 'docker info'` inside a
  verify is a question, and to call that a workaround would forbid the one use that is
  always right.
- **`prefix`** — names its position on a line, which is incidental. `AWS_PROFILE=x cmd`
  is a prefix; `env -u AWS_PROFILE cmd` is a prefix; a modified `$PATH` is neither, and
  wraps all the same. the term must name what it DOES.
- **`harness`** — a harness runs a subject under measurement and reports on it. a wrapper
  emits no report; it changes what the subject receives. the two differ in direction.
- **`helper`** — says no word about what it does, and is forbidden repo-wide
  (`rule.forbid.term=helpers`). the single worst name for a thing whose whole point is
  that a reader must judge whether to keep it.

## .evidence

- `rule.require.identical-commands-on-every-server.md` — the rule this term serves, and
  which carries the 0-vs-31 tally as its own measurement
- `src/grove.provision/5.devtools/5.8.docker/provision.verify.sh` — the legitimate
  permanent kind: `sg docker -c 'docker info'` asks *"would a fresh login reach it?"*,
  which is a question a bare `docker info` cannot pose from a stale session
- `term=probe._.choice.reason.md`, the sixth hazard — the same round produced a probe
  that answered about a shell no program would ever run. a wrapper and a mis-aimed probe
  are the same error seen from two sides: both supply or inspect the wrong context

## .disputes

### dispute: `shim` — raised 2026-08-06 — status: RESOLVED (a distinct term)

- raised.by  = mechanic, who had already called the `sg docker` layer a "shim" in prose
- claim      = the glossary already holds `shim` for "a thing at a path callers know that
               leads to the real one". `sg docker -c 'rhx …'` is a thing in front of a
               command that leads to it, so it is a shim and needs no second word.
- counter    = `term=shim`'s own `.test` excludes it in one line: *"a file that transforms
               args, adds a retry, or prints its own report is a wrapper, not a shim"* —
               the word `wrapper` was already load-bear there, undeclared.

               and the distinction decides an ACTION, which is what makes it worth a
               term rather than a nuance. a shim is correct permanently: deletion of it
               loses a path. a wrapper is correct only until the gap it names is closed:
               deletion of it is the goal. to merge them is to give a wrapper a shim's
               lifetime, and the concrete cost was measured this round — a 31-test run
               reported as progress when the box was still broken.
- resolution = declare `wrapper` as its own term, opposite `shim` on the
               does-it-add-behavior axis. record `shim` as a forbidden synonym of
               `wrapper` (and the reverse already stood in `term=shim`). dispute closed.
