# rule.require.smoketest-before-a-grove-is-declared-ready

## .what

**no grove is ready until `git.grove.provision test` passes on it.** that one command is the
acceptance criteria — not a green `grove.provision`, not a converged plan, not a human's
read of the logs.

```sh
rhx git.grove.provision test <name>
```

exit 0 means the box did a real job end to end: it synced `ahbode/svc-chat` to latest
`origin/main`, installed its deps, provisioned a testdb, and ran the integration suite to
a green tally. any other exit code means the grove is **not** ready, whatever else looks
green.

## .why a JOB, and not a checklist

every other signal this repo produces is a claim ABOUT the box. the smoketest is the box
DOING the work, which is the only evidence that cannot hold true while its prediction is
false.

⇒ **a converged box is not a capable box.** the bundle tree declares what a machine HAS;
only a job proves what it can DO.

.refs = rule.require.smoketest-before-a-grove-is-declared-ready.demo=converged-but-not-capable, m1

## .why it must be DETERMINISTIC, and how it is

a gate whose verdict depends on who ran what by hand is not a gate. so the smoketest
**establishes** every precondition rather than assumes it — the sync, the deps, and the
fixture are steps 1-3, run every time.

that is the line between it and `git.grove.ready.verify`:

| | reads | writes | verdict depends on |
|---|---|---|---|
| `git.grove.ready.verify` | yes | never | **the box AND its prior hand-setup** |
| `git.grove.provision test` | yes | its own fixtures | **the box** |

`git.grove.ready.verify` HALTS when deps are absent and names the fix. that is right for a
diagnostic and useless as a gate.

⚠️ **`latest origin/main`, never a pinned sha.** svc-chat's main is green by invariant —
cicd gates it — so latest main is a fixed point that needs no keeper, where a pin goes
stale and grows one. the cost of that choice is named where it lands: step 4's halt says
*"UNLESS main shipped red, which this gate trusts it never does"*, and prints the
`gh run list` that settles it.

## .when it is required

| moment | required? |
|---|---|
| a new grove, before any work is sent to it | **yes** — this is the acceptance gate |
| a REBUILT box adopted onto an extant exid | **yes** — a new disk is a new box |
| after a change to the bundle tree, proven on a grove | **yes** — that is what "proven" means |
| a grove that has sat idle and is woken again | recommended; cheap, and it catches drift |

## .what it does NOT replace

- `grove.provision --mode plan` — still the way to see WHAT a box lacks. the smoketest says
  only that the box works, never which bundle is short
- `git.grove.ready.verify` — still the diagnostic. it halts one rung at a time with a precise
  fix, and the smoketest CALLS it (step 0) rather than duplicate it
- `rule.require.prove-each-bundle-plan-apply-apply` — that proves a BUNDLE; this proves a
  BOX. both are owed

## .the test

> has this grove run a real job end to end, in one command, since it was last built?

- yes, exit 0 → ready
- no → **not ready**, and a green plan does not substitute

## .enforcement

- a grove declared ready, or handed work, with no smoketest that passed = **blocker**
- a rebuilt box adopted onto an extant exid with no fresh smoketest = **blocker**
- a howto that ends at `grove.provision` and calls the box ready = **blocker** (it must end
  at the smoketest)
- a smoketest that ASSUMES a precondition rather than establishes it = **blocker** (its
  verdict is then about the last human, not about the box)

## .see also

- `rule.require.smoketest-before-a-grove-is-declared-ready.demo=converged-but-not-capable` —
  the measurement behind this rule
- `.agent/repo=.this/role=any/skills/git.grove.provision.test.sh` — the gate, and why each step may
  write when `rule.forbid.repair-plays` forbids exactly that
- `.agent/repo=.this/role=any/skills/git.grove.ready.verify.sh` — the diagnostic it calls
- `rule.require.prove-changes-on-a-grove` — a change is unproven until it RUNS on a grove
- `rule.forbid.repair-plays` — why the smoketest refuses to clone the tree (that is
  `5.10.repos`, and bundle-owned)
- `howto.add-a-new-grove` / `howto.adopt-a-replacement-grove` — both end here
- `gotcha.the-duct-returns-the-send-not-the-answer` — why every step rides `--bare`
