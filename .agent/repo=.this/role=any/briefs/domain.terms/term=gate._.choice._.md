# domain.term: gate

term.chosen   = gate
term.kind     = noun
term.synonyms.forbidden:
- check        (a check REPORTS; a gate DECIDES. every gate is a check, and a check is a gate
                only where later work is skipped on its answer — see `.what`)
- guard        (bhrain's route vocabulary already binds `guard` to a stone's validation file.
                to reuse it here would overload one word across two repos' contracts)
- barrier      (names an obstruction, so it reads as a defect rather than as a designed decision)
- condition    (names the EXPRESSION, never its role. `[[ -t 0 ]]` is a condition; it becomes a
                gate only once a branch turns on it)
- checkpoint   (implies a resumable waypoint — a place you pass and record. a gate is a fork)
- guarantee    (a gate ASKS and decides on the answer; a guarantee asks no one and makes the
                bad case unreachable. `sudo -n` is the worked example of the second — see
                `term=guarantee._.choice._.md`)

## .what
a **gate** is a check whose answer decides whether later work RUNS.

it is a **role**, never a kind of artifact. the same check is a gate in one position and a
report in another — what makes it a gate is that a caller skips work on its verdict:

| the check | what turns on it | gate? |
|---|---|---|
| `provision.verify` | `bundle_leaf` SKIPS `configure` when it fails | **yes** |
| `configure.verify` | a claim is printed, and no phase is skipped | no — a report |
| `[[ tier == local@unix && -t 0 ]]` | whether an interactive prompt may open | **yes** |
| `git.grove.provision test` | whether a grove may be declared ready | **yes** |

⇒ so *"is this a gate?"* is answered by what happens NEXT, never by the check itself.

## .why the distinction is load-bear
a check read as a report gets softened when it is noisy; a gate cannot be softened without a
silent skip. `rule.require.upgrade-entries-verify-themselves` says it in those words — *"a
gate, not a report: if this fails, configure is SKIPPED"* — and the whole reason the
provision/configure split holds is that one verify occupies the gate position.

## .the scales it spans, and why they are ONE concept
measured across 15 briefs, 2026-08-13: every use fits one sense, at four scales.

```
an expression   the tier+tty conjunction before a `read -rp`
a phase         provision.verify, before configure runs
a tunnel rung   the ssm gate, before the duct binds
a whole verb    git.grove.provision test, before a grove is declared ready
```

⚠️ do NOT split these into separate terms. the scale varies; the concept does not — a check,
and later work that does not run when it says no.

⚠️ nor split by the SHAPE of the refusal. `prove.sudo-is-gated-or-nonintera` reports a
decline-gate and an assert-gate as distinct rows, and both are one term: each asks whether
root is available and skips later work on the answer. what differs is how gracefully it
refuses, which is a legibility property of that gate rather than a second concept.

## ⚠️ .the neighbour it is most often confused with
a **guarantee** is not a gate, and one artifact can be both. `pkg_assert_sudo` is a poor
gate (it fails the phase rather than declines) and a sound guarantee (it is `sudo -n true`,
so no prompt is reachable below it). on 2026-08-13 a true citation about its GATE half was
used to judge its GUARANTEE half, and a check condemned nine correct sites.

⇒ when a claim touches one of these, say which half it is about
(`term=guarantee._.choice.reason.md`, `.the boundary against gate`).

## .refs
- src/bundle.upgrade.sh                                          # `bundle_leaf`, the phase gate
- src/grove.pkg.sh                                              # `pkg_can_sudo`, the root gate
- src/grove.provision/5.devtools/5.4.gh/configure.upsert.sh       # a prompt gate
- src/grove.provision/5.devtools/5.15.identity/configure.upsert.sh
- src/grove.provision/2.shell/2.3.ssh/configure.upsert.sh
- .agent/repo=.this/role=any/briefs/grove/provision/rule.require.upgrade-entries-verify-themselves.md
- .agent/repo=.this/role=any/briefs/evidence/rule.forbid.tty-as-a-proxy-for-a-human.md

## .reason
see the ref-level cluster beside this choice:
- `term=gate._.choice.reason.md` — why it was itemized late, the gate-vs-verify boundary, and
  the one-sense measurement that settled it against a split
