# domain.term: lens

term.chosen   = lens
term.kind     = noun
term.synonyms.forbidden:
- simulation   (says the run is FAKE. a lens run is real code, reading a real box — only its
                subject is hypothetical)
- preview      (a plan is a preview of THIS box; a lens previews a DIFFERENT one. the word
                cannot tell them apart, and the difference is the whole term)
- pretend      (says the box is lying about itself. the box is not — the CALLER named a
                subject the box is not)
- what-if      (a phrase, not a noun, and it names every plan equally)

⚠️ the word `rule.forbid.term=dryrun` bans is forbidden here too, and for a SECOND reason: that
rule bans it as a MODE spelling, and a lens is a property of the SUBJECT. so it is wrong on
both axes at once, which is what makes it the most tempting wrong word for this concept.

## .what
a run whose declared subject is **a box other than the one it stands on**. it may READ, and it
may never WRITE.

it arises exactly one way: `--for` contradicts the tier the platform probe found. `--for` sets
only the TIER — the platform comes from a probe alone — so an override cannot name a new box
class. it can only produce a contradicted pair, and there are exactly two:

| the pair | what the caller asked |
|---|---|
| `cloud@unix` | a box with a real desktop session, told to act headless |
| `local@aws.ec2` | a grove, told a human is at its keyboard |

**neither is a machine we own.** each is the reader asking *"what would the OTHER kind of box
get?"* — which is a legitimate plan, and never an apply.

## 🛑 .a lens may not write

`grove.provision._.sh` halts a contradicted `--for` on `--mode apply`, and only on apply.

the cost is not hypothetical. measured 2026-09-03, redteam round 24 (F1/F1b):

- `--for cloud` on a laptop → `2.3.ssh` reads `== cloud@*`, installs the `ssh` METAPACKAGE, and
  returns BEFORE the stop/disable/mask. its verify rung 3 tests `!= cloud@*`, so the one check
  written to catch it goes silent. end state: sshd on `0.0.0.0:22`, enabled at boot
- `--for local` on a grove → the same gate falls the other way and MASKS sshd on a headless
  box with no console

⇒ **a bundle decides by a test of `$GROVE_ENV_SERVER`.** so under a lens each bundle converges
for a box that is not this one, and the bundles that gate hardest on the tier are the ones that
touch the perimeter.

## ⚠️ .a lens is not a MODE, and `plan` is not a lens

they are two axes, and the round that found this defect found it by keeping them apart:

| axis | question | values |
|---|---|---|
| **mode** | does this run WRITE? | `plan` · `apply` |
| **lens** | which box is the SUBJECT? | this one (the probe's) · another (a contradicted `--for`) |

a plan on the probed box is not a lens — same subject, no write. a lens on `--mode plan` is the
useful cell. a lens on `--mode apply` is the empty one, and is what the halt refuses.

⇒ this is why the halt sits in the DRIVER and not in `grove_env_derive`: the mode is a property
of the RUN, never of the box (`grove.provision._.sh:312`), and a mode test inside the derivation
would be the coupling that line forbids.

## .the natural tier — what makes a lens detectable at all

`grove.env.sh` exports `GROVE_ENV_TIER_NATURAL` beside `GROVE_ENV_SERVER`: the tier the platform
probe found, before `--for` had its say. a lens is exactly the disagreement between the two.

⚠️ **an EMPTY natural tier is not a match and not a mismatch.** it means no probe ran, because
the caller named the box whole via `GROVE_ENV_SERVER` — which `grove.env.sh:427-429` names as
the documented way to override a wrong derivation, and which sets the platform too. the gate has
no subject there and stays silent (`rule.forbid.failhide`).

## .refs
- `src/grove.env.sh` — the probes, and `GROVE_ENV_TIER_NATURAL`
- `src/grove.provision._.sh` — the halt, beside `GROVE_MODE`
- `src/grove.for.sh` — the `--for` axis this term is a property of

## .reason
see the ref-level cluster beside this choice:
- `term=lens._.choice.reason.md` — etymology, the round-24 measurement, why the first fix was wrong
