# domain.term: ground

term.chosen   = ground
term.kind     = noun
term.synonyms.forbidden:
- admin (says WHO may log in, not what the user is for; every box has an "admin" and the
  word carries no grove metaphor)
- root (taken by unix, and wrong — `ground` is not uid 0, it is a user that may sudo)
- keeper (a live dispute, not a habit — see `.reason`; it reads more symmetric with
  `camper` and lost on the human's word)
- groundskeeper (the full form; correct in prose, too long for a name typed at every ssh)
- sudoer / operator / maintainer (generic sysadmin words with no bounded context)

## .what
the grove user that **holds sudo** and converges the box's SYSTEM state. it is reachable only
by an admin ssh key that the agent does not hold.

its pair is `camper`, the user the agent runs as, which holds **no** sudo and is **not** in
the `docker` group.

| user | sudo | reachable by | runs |
|---|---|---|---|
| `ground` | yes, NOPASSWD | an admin ssh key the agent lacks | system convergence |
| `camper` | **no** | its own ssh key | the agent, its duct, its trees |

## ⚠️ .a run from `ground` does NOT converge the other homes
🛑 **`ground` is privileged, not universal.** it does NOT configure every user's home, so one
run from it does not converge the machine. 📜 measured 2026-08-12 on a fresh box, in one line:

```
getent passwd camper ground
camper:x:1002:1002::/home/camper:/bin/bash        ← ground's run left this alone
ground:x:1001:1001::/home/ground:/usr/bin/zsh
```

ground's apply had already reported `done` with zero claims. camper still needed its OWN
`grove.provision`, which then did the full work — wrote camper's rack manifest, cloned into
`/home/camper/git`, installed into `/home/camper/.local/bin`.

⇒ **each seat converges its own home.** `ground` is the only seat that can converge SYSTEM
state (packages, units, sysctl), and it converges `$HOME` for exactly one home — its own.

⚠️ so read a green ground run for exactly what it proves. `ground — ✔ 127 · ✋ 0` does NOT
mean the box is ready; it means ground's half is ready, and the camper is unmeasured until
it runs too.

## ⚠️ .`camper` is not in the `docker` group, and reaches docker anyway
the table row above is accurate; the inference a reader draws from it is not. measured
2026-08-12 on the same box:

```
id -nG camper                              →  camper
docker context inspect --format …Host      →  unix:///run/user/1002/docker.sock
```

uid 1002 IS camper. it reaches docker through a **rootless daemon of its own**, in its own
runtime dir — so the group is not the mechanism, and its absence costs no capability. that
same hour camper pulled an image and ran a postgres container for a test suite.

⇒ do not "fix" the absent group membership. the rootless daemon is the design, and to add
`camper` to the `docker` group would hand it root-equivalent reach on the host — the exact
privilege this seat split exists to withhold.

## ⚠️ .the split is CUSTODY, not a password
the control is *who holds the key*, never *who knows a password*. a duct **is** tmux, so a
`sudo` password prompt sits on the pane and eats the next command sent down it. a password
would convert every privileged step into a hang — which is why every headless step in this
repo already refuses to prompt.

## .the metaphor it belongs to
`forest` → `grove` → `tree` is the extant family. `camp` is already this repo's word for
grove infrastructure (`.agent/keyrack.yml` declares `AWS_PROFILE` at `env.camp`). so:

- **`camper`** — the one who camps in the grove. INHERITED: the image names this user, and
  the name has changed between images (`ec2-user` → `camper`)
- **`ground`** — the one who tends the grounds. MINTED here

## .refs
where the term is used:
- ahbode/infrastructure                                                  # the seat is BORN there: rule.forbid.camper-sudo.md, plus the userdata that writes the sudoers grant
- .agent/repo=.this/role=any/skills/git.grove.ready.verify.sh               # rung 4 climbs BOTH seats, and names which converges
- ~/.ssh/config                                                          # the two aliases: `<exid>.ground` and bare `<exid>` for the camper

## .reason
see the ref-level cluster beside this choice:
- `term=ground._.choice.reason.md` — the etymology, the `keeper` dispute, and why a unix
  username is the least reversible name in the system
