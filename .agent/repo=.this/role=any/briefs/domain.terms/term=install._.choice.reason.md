# domain.term.choice.reason: install — ⛔ RETIRED

⛔ the word is retired; see `term=install._.choice._.md` for what replaced it. this file is kept
for the **measurements**, which are real and outlived the term they were written to justify
(`rule.require.briefs-obey-the-prose-rules` carves out a record of a measurement).

## .etymology — and why it argued for the wrong side

latin *installare* — *in-* (into) + *stallum* (a stall, a seat). to seat an occupant **in its
place**. the word entered english for the seat of a cleric in a choir stall, and only later for
machinery.

that origin says a seat can be re-taken: the seat is the constant, the occupant may be replaced.
it was read here as an argument that `install` covers re-delivery and `provision` does not.

⚠️ **it lost.** the human settled the whole family on `provision` (2026-08-31), and the etymology
was the weakest evidence in the room — a word's latin root says what it once meant, never what a
domain has already chosen. `rule.require.persist-domain-term-evidence` asks for etymology as ONE
input; this cluster let it outvote a live decision.

## ✅ .the two columns — the measurement that still holds

a read of the retired `src/install_env.pt1.system.performance.sh` on 2026-09-06 found roughly
**7** operations that wrote a repo-authored executable into `~/.local/bin` by heredoc,
unconditionally:

```sh
install_machine_resource_procs_find_orphan() {
  local bin_path="$HOME/.local/bin/machine_resource_procs_find_orphan"
  mkdir -p "$HOME/.local/bin"
  cat > "$bin_path" << 'ORPHAN'
  ...
```

there is no absence test anywhere in it. set beside a true fetch (`install_rust`, a no-op on
re-run), the split is total:

| | a fetch | a re-delivery |
|---|---|---|
| source of truth | an upstream registry | this repo's `src/` |
| what it tests | is the tool absent? | *(it tests none of it — it overwrites)* |
| a re-run | a no-op | the entire purpose |
| its failure | a fetch that half-completed | a copy that never left the repo |

⇒ **main resolved this, and by a better move than a wider verb.** the seven are now `asset`s:
real files under `src/machine/`, copied by a bundle phase, so the phase's verify can `cmp` the
live copy against the checkout. one word stopped being owed the moment the second column got a
second copy to be compared against.

## ⚠️ .why staleness is invisible — the measurement that motivated `asset`

a fetch fails **loudly**: the fetch errors, or the binary is absent when called. a re-delivery
fails **silently**: the old copy is present, executable, and answers when called. no signal at
all.

on 2026-09-06 that gap ran for hours:

```
src/install_env.pt1.system.performance.sh        →  5 hits for UNSEEN_INFO   (fixed)
~/.local/bin/machine_resource_procs_find_orphan  →  0 hits                   (stale)
```

the repo held a fix that split kernel-attested strays from `unseen` paths. the machine held the
version that joined them with a single `||`. so `machine.usage.diagnose` — which reads the
installed binary — printed:

```
🪄 kill -9 1426679 1426683 1426742 1427468 1432340 1432537 ...
```

six of those were healthy chrome zygotes. **the repo had already deleted that advice.**

the third shape of one family defect, and the sharpest:

| layer | what was reported | what was true |
|---|---|---|
| a sync (09-03) | a copy succeeded | it delivered the wrong file |
| a configure (09-06) | prefs were written | the live process never re-read them |
| **an install** (09-06) | *(no report at all)* | the machine ran a copy the repo had superseded |

the first two report a step and mislead. the third **reports no step**, because an install has no
cadence — you run it once at machine setup and never think of it again. so a stale copy has no
moment at which it would be noticed.

> **a configure lies about its outcome. an install stays silent about its currency.** the second
> is worse, because silence never prompts a check.

⇒ that sentence is the case for `term=asset`, stated before the word existed here.

## ⛔ .the argument that is now flatly false

this cluster argued the seven must retain an `install_` prefix, because
`rule.require.root-install-invocation` grepped for it and that grep had caught
`install_starship`, defined and never called.

**both halves are gone:**

- the rule was renamed `rule.require.every-function-has-a-driver`, and it dropped the prefix test
  outright: *"**any** declared function that no phase chain reaches = blocker — no prefix is
  exempt"*
- the seven are no longer functions at all. they are files, and a bundle phase copies them

⚠️ so the lesson is not about installs. it is about a **term propped up by a check**: this
cluster's whole reason to hold a word was that a grep depended on it. a grep is cheap to rewrite
and a vocabulary is not, so that is the tail that wags the dog — and the grep was rewritten
anyway, four weeks before this file claimed it could not be.

## ✅ .the follow-on it left open, now CLOSED

this cluster closed with: *"a `machine.diagnose.drift` — compare each `~/.local/bin/*` against
the heredoc that declares it — would close the gap."*

that gap is closed, by a bundle rather than a diagnose: an `asset` is `cmp`'d by its own phase's
verify on every `grove.provision` run, so drift is a ✋ on the box that has it rather than a
report a human must remember to ask for. `rule.require.upgrade-entries-verify-themselves`.

## .the neighbours

- **`asset`** — what the re-delivery column became, and the term that carries every measurement
  above
- **`grove.provision`** — the verb that replaced this one, repo-wide
- **`proxy`** — "the install was run at setup" substituted for "the machine holds the declared
  copy", with the condition (no repo change since) unstated. still the shape of the defect
- **`diagnose`** — the victim: a stale binary is what made a diagnose pass sentence on six
  healthy processes
