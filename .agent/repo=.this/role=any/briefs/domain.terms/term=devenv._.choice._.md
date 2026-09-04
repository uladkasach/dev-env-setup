# domain.term: devenv

term.chosen   = ⛔ FORBIDDEN — see `.status`
term.kind     = noun (retired)
term.retired.in.favor.of:
- grove             # the MACHINE the configs land on
- bundle            # the UNIT of the inventory
- tree              # the INVENTORY itself
- grove.provision   # the VERB that converges one
- git.repo.pull     # the remote → here half of the retired `sync`
- grove.bootstrap   # the act that puts this repo on a bare machine

## ⛔ .status = FORBIDDEN repo-wide (human, 2026-09-02)

> *"devenv is not allowed anywhere. forbidden now."*

this cluster is the **tombstone for the whole `devenv.*` family**. it is kept, rather than
deleted, for one reason: the word is still in a human's muscle memory, and a reader who meets
it in a git history, on an old grove, or under their own fingers needs one place that says what
it became.

⚠️ it is the ONLY place the word may appear. every contract — filename, function name, command,
env var, config fence — is at zero.

## .what it used to name
the set of development-environment configs + tools this repo installs onto a machine.

## 🛑 .why no replacement noun was coined

the concept had no work left to do. three live terms already carry every part of it:

| the old noun said | reach for |
|---|---|
| "the machine it lands on" | `grove` |
| "one unit of what lands" | `bundle` |
| "the whole set that lands" | `tree` — the bundle tree IS the inventory |

⇒ a fourth word for the union of three would be vocabulary for its own sake
(`rule.forbid.domain-term-synonyms`). prose that read *"a grove's state IS its bundle tree"* now reads
*"a grove's state IS its bundle tree"*, and loses no sense.

## .the whole family, and what each became

| retired | reach for | why |
|---|---|---|
| `devenv` (noun) | `grove` / `bundle` / `tree` | the union of three live terms |
| `devenv.upgrade` | `grove.provision` | the human picked it 2026-08-31 |
| `devenv.install` | `grove.provision` | superseded in two hops: `install` → `upgrade` → `provision` |
| `devenv.install.step` | `bundle` | the `step <tag> <fn>` driver was deleted; a bundle is the unit |
| `devenv.sync` | `grove.provision` + `git.repo.pull` | `sync` named BOTH directions — one word, two ways |
| `devenv.pull` | `git.repo.pull` | the noun now carries the split from `git.grove.pull` |
| `devenv.bootstrap` | `grove.bootstrap` | same act, current noun |

## .refs
- `term=grove.provision._.choice._.md` — the verb that replaced the core of this family
- `term=git.repo.pull._.choice._.md` — the remote → here half
- `term=grove.bootstrap._.choice._.md` — the bare-machine act
- `term=grove._.choice._.md` / `term=bundle._.choice._.md` / `term=tree._.choice._.md`

## .reason
see the ref-level cluster beside this choice:
- `term=devenv._.choice.reason.md` — etymology, the two-hop supersession, evidence
