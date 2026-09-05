# domain.term: desktop

term.chosen   = desktop
term.kind     = noun
term.synonyms.forbidden:
- graphical    (names how the SESSION draws, not what the box is. a headless x11 session is
                graphical and has no human — see `.reason`)
- gui          (an interface style, and an acronym besides (`rule.forbid.shouts`))
- screen       (already the name of a terminal multiplexer, and `grove_env_has_screen` was deleted
                on 2026-07-29 for a claim it could not check)
- display      (an X concept, and `DISPLAY` is one of the SIGNALS this probe reads — the input, not
                the answer)
- interactive  (a property of a shell, not of a machine. a duct is interactive and has no human)

## .what
a machine with a screen a human is presently sat at.

it is one half of this repo's closed platform set, and it is the value `$server` carries as
`local@unix`:

| `$server` | desktop? | the box |
|---|---|---|
| `local@unix` | **yes** | a laptop, at its own keyboard |
| `cloud@aws.ec2` | no | a grove |

## .why the word is load-bear
`desktop` is what every interactive gate in the bundle tree turns on:

```sh
[[ "$GROVE_ENV_SERVER" != "local@unix" ]] || <offer the human a prompt>
```

so the word decides whether a box is offered a prompt. read it wrong on a headless machine and
`ssh-keygen` opens a passphrase dialog onto a duct with no tty to answer it — measured 2026-07-30.

## .the two facts it welds, deliberately
`desktop` asserts BOTH *a screen exists* and *a human is at it*. that weld is the point: the two are
separable in principle, and this repo has no box where they differ, so one word is honest and two
would be speculative.

> the box where they DO differ is a ci runner — `local@cicd`, local tier, no screen, no human. we do
> not detect it, and `term=probe._.choice.reason.md` records why an unrun probe stays out. if such a
> box ever arrives, `desktop` splits before it is reused.

## .refs
- src/grove.env.sh                                              # `grove_env_probe_desktop`
- .agent/repo=.this/role=any/briefs/grove/provision/howto.detect-env-server.md    # rung 2 of the ladder, and its tests
- src/grove.provision/2.shell/2.2.git/configure.upsert.sh          # a gate that turns on it
- src/grove.provision/2.shell/2.3.ssh/configure.upsert.sh          # a gate that turns on it
- src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh           # a gate that turns on it

## .reason
see the ref-level cluster beside this choice:
- `term=desktop._.choice.reason.md` — why `graphical` was declined, why the deleted `has_screen`
  predicate is a cautionary precedent, and the dated evidence that a probe which reads
  `XDG_SESSION_TYPE` by PRESENCE calls a headless box a desktop
