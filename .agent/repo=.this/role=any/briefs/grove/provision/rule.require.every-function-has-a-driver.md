# rule.require.every-function-has-a-driver

> was `rule.require.root-install-invocation`. that name carried a superseded verb and named a
> deleted mechanism; this one names the principle, which outlived both.

## .what

**every** function this repo declares must be REACHED by a phase that `bundle.upgrade`
drives. whatever its name, whatever file it sits in.

the prefix does not matter. `install_*`, `configure_*`, `clone_*`, `upgrade_*` — the defect
is identical in each case: **a declared function no one drives.**

## .what counts as DRIVEN

a function is driven when a chain of calls reaches it from one of the four phase functions
of a leaf:

```
bundle.upgrade <slug>
  └─ grove_provision_<slug>_provision_upsert    ← one of these four
     └─ some_operation                          ← driven
        └─ another_operation                    ← also driven, via the chain
```

the four phase entrypoints are the ONLY roots:

| phase | function |
|---|---|
| `provision.upsert` | `grove_provision_<slug>_provision_upsert` |
| `provision.verify` | `grove_provision_<slug>_provision_verify` |
| `configure.upsert` | `grove_provision_<slug>_configure_upsert` |
| `configure.verify` | `grove_provision_<slug>_configure_verify` |

a leaf's `_.sh` may declare operations shared by its own phases — those are driven, because
the phases call them. what violates this rule is a function reached by **no** chain that
starts at a phase.

> ⚠️ follow the chain all the way to a phase. a function called only by another function
> that is itself undriven is still dead code — a dead cluster is no better than a dead line.

## .why

- the bundle tree is the inventory (`rule.require.bundle-as-sole-declaration`), and a
  function outside every phase's reach is in no inventory at all
- a human expects one `grove.provision` run to converge the whole env
- dead code that *looks* load-bearing is worse than an obvious gap, because a reader trusts
  the name and stops looking

### measurement 1 — `install_starship`, absent from every fresh machine

it was declared and never invoked. the prompt was simply missing on each new box until
somebody noticed by eye. no error, no red line — the function existed, so a reader who
grepped for it concluded starship was handled.

### measurement 2 — `clone_this_repo`, driven and inert all the same

> ⚠️ **this measurement said the wrong thing for as long as it existed.** it read
> *"declared, sourced, driven by no step, dead its whole life"* — and one command disproves
> the middle clause:
>
> ```
> git show origin/main:src/install_env._.sh
> …
> install_gh_cli
> clone_this_repo      ← it is right there, on the driver's list
> install_zsh
> ```
>
> the function WAS driven. it was still dead, for a different and sharper reason. the
> conclusion survived; the cited evidence did not — which is what
> `rule.require.trust-but-verify` warns about, and it happened here in a brief this repo
> reads to decide what counts as proof.

the first draft of this rule named two prefixes — `install_*` and `configure_*`. a function
called `clone_this_repo` walked straight through that gap by NAME, so no prefix check would
ever have looked at it.

and it was dead code that **looked load-bearing**: its name implied it was how the repo
reached a new machine. in truth it could never have worked — to call it you must already
have sourced the file that contains it, so it was circular, and it cloned over ssh, which no
fresh machine can do. it sat on the driver's list, ran on every install, and converged
precisely no state.

so **a driver line is not the claim this rule is really after.** a function can be listed and
still do no work. the rule asks that every function be REACHED by a phase whose claim is then
VERIFIED — which is why `rule.require.upgrade-entries-verify-themselves` is its pair, and why
a prefix list was the wrong shape twice over: it exempts every other verb, AND it counts a
mention as a drive.

## .how — when you add a function

1. put it in the leaf that owns the concern: a phase file, or the leaf's `_.sh` if more than
   one phase of that leaf needs it
2. call it from a phase — or from something a phase already calls
3. confirm with `--mode plan`, which accounts for every item at every depth

```sh
rhx grove.provision --mode plan              # this machine's view
rhx grove.provision --for cloud --mode plan  # a grove's view
```

a function reached by no phase appears nowhere in that plan. **that absence is the defect
this rule catches** — so read the plan for what is missing, not only for what is red.

## .where a function may live

| location | driven by |
|---|---|
| a phase file | it IS a phase entrypoint, or is called by one |
| a leaf's `_.sh` | the phases of that leaf |
| `grove.for.sh`, `grove.env.sh`, `grove.pkg.sh` | shared runtime — phases across the tree call these |
| `bundle.upgrade.sh` | the runtime itself; it drives the phases |

`bash_aliases.sh`, `ductwork.sh`, `termwork.sh` are **installed artifacts**, not part of the
run. their functions are driven by a human at a shell, and `2.7.aliases`'s verify is what
proves a caller finds them — see `rule.require.seam-claims-have-an-owner`.

## .the one exemption

`grove.bootstrap.sh` sits at the repo ROOT, outside the bundle tree. it runs *before* the
repo exists, so it cannot be a step of the very run it starts. it is the one artifact allowed
to stand alone — and the readme is what drives it.

a function inside the bundle tree may **never** claim this exemption. that is precisely the
mistake `clone_this_repo` embodied: a bootstrap concern written in a file that only loads
once the bootstrap has already succeeded.

### 🛑 an exemption is also a BLIND SPOT — measured 2026-08-13

`grove.bootstrap.sh` held a **bare** `sudo apt-get update && sudo apt-get install -y git`
— no `DEBIAN_FRONTEND`, no `NEEDRESTART_MODE`. `grove.pkg.sh`'s own header records what a
bare apt call cost a grove: needrestart drew its interactive menu, waited forever with no
human to answer, held the dpkg lock, and ate every command sent down the duct. **57 minutes.**

that was fixed across the whole bundle tree by `PKG_APT_ENV`. this file did not get the fix,
for two independent reasons — and both are properties of the EXEMPTION, not of the code:

| # | why it survived | the general shape |
|---|---|---|
| 1 | it sits OUTSIDE `src/`, and every sweep that found the other nine ran `--path src` | an exempt artifact is outside the paths the enforcement scans |
| 2 | its branch is behind `command -v git \|\|`, so it is unreachable on any box that HAS git — i.e. every box this repo has ever converged | an exempt artifact runs on a code path nobody re-tests |

⇒ **an artifact exempt from a RULE is usually also exempt from the SWEEP that enforces it.**
the exemption was granted for one reason (it runs before the repo exists) and silently bought
a second exemption nobody granted: invisibility to every check the rule implies.

### .the second question to ask when you grant an exemption

`rule.require.exemptions-name-their-trigger` asks the first: *what fires this exemption?*
this measurement adds the second:

> **what CHECKS does this artifact now escape, and which of them did it still need?**

the bootstrap genuinely needed the tree's package-manager DETECT to stay out (three
candidates, three ways to drift) and genuinely needed its apt GUARANTEE to come along. the
exemption made no distinction, so it dropped both.

⚠️ and its own header argued the drop was safe. it claimed the apt ASSERT was the ONLY
duplication, and reasoned — correctly — that an assert is cheap to duplicate because it has
one branch and one message. that argument was sound and was applied to the wrong half:

> a copy of a **guarantee** is worth more than a copy of a **check**, because a check that
> drifts reports, and a guarantee that drifts **hangs**.

## .enforcement

- **any** declared function that no phase chain reaches = **blocker** — no prefix is exempt
- a bootstrap concern written inside the bundle tree = **blocker** (it belongs in
  `grove.bootstrap.sh`; a file that loads after the repo is present cannot fetch the repo)
- a function reachable only from another undriven function = **blocker** (a dead cluster)
- a guarantee the bundle tree relies on (`PKG_APT_ENV`, a noninteractive env, a lock guard)
  absent from `grove.bootstrap.sh` = **blocker** — the exemption covers the DETECT, never
  the guarantee
- a sweep that enforces a tree-wide rule and scans only `src/` = **blocker**; the one exempt
  artifact is the one most apt to have drifted

## .see also

- `rule.require.bundle-as-sole-declaration` — the tree IS the inventory
- `rule.require.grove-provision-bundles` — a new member is born a bundle
- `rule.require.upgrade-entries-verify-themselves` — a driven function is not a proven one
- `rule.require.exemptions-name-their-trigger` — extracted from this rule's one exemption
- `rule.require.idempotent-install-procedures` — every phase must tolerate a re-run
- `readme.md` — the human's entrypoint, and the sole driver of `grove.bootstrap.sh`
