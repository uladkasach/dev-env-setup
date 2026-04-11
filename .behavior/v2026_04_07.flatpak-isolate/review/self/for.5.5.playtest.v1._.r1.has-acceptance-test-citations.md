# self review: has-acceptance-test-citations (r1)

## the question

cite the acceptance test for each playtest step.
- which acceptance test file verifies this behavior?
- which specific test case covers it?
- if a step lacks coverage, is this a gap or untestable?

---

## check for acceptance tests

### search for acceptance tests

```
tests/
├─ verify_isolation.sh
└─ verify_wayland.sh
```

these are **verification procedures**, not acceptance tests.

| file | type | purpose |
|------|------|---------|
| verify_isolation.sh | manual verification | check ptrace/proc blocked |
| verify_wayland.sh | manual verification | check x11/wayland sockets |

### what is an acceptance test?

an acceptance test is automated code that:
1. runs in CI
2. exercises the system as a user would
3. asserts on observable outcomes

this project has **no acceptance tests** in the traditional sense.

---

## why no acceptance tests?

### environment constraints

the verification procedures require:
1. **wayland compositor** — not available in CI
2. **sudo access** — not available in CI
3. **display** — not available in CI
4. **firefox flatpak** — not installed in CI

CI environments cannot run these verifications.

### the blueprint explicitly deferred automation

from `3.3.0.blueprint.factory.v1.i1.md`:
> **deferred:** CI automation — no wayland compositor in CI

the factory blueprint acknowledged this constraint and chose manual verification.

---

## map playtest steps to verification procedures

| playtest path | verification | type |
|---------------|--------------|------|
| path 1: apply yama ptrace_scope | configure_yama_ptrace output | procedure feedback |
| path 2: apply firefox isolation | configure_firefox_isolation output | procedure feedback |
| path 3: verify isolation | verify_isolation.sh | manual procedure |
| path 4: verify wayland | verify_wayland.sh | manual procedure |
| path 5: file picker works | manual observation | human verification |

---

## are these gaps or untestable?

| step | gap or untestable? | reason |
|------|-------------------|--------|
| path 1 | untestable in CI | requires sudo |
| path 2 | untestable in CI | requires flatpak |
| path 3 | untestable in CI | requires wayland + display |
| path 4 | untestable in CI | requires wayland + display |
| path 5 | untestable in automation | requires human observation |

**all steps are untestable via automation** due to environment constraints.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| acceptance tests exist but not cited | search tests/ dir | no — only verify_*.sh |
| tests could run in CI | check prereqs | no — wayland required |
| playtest could be automated | check each step | no — all need env |

---

## why it holds

1. **no acceptance tests exist:** verified by file search
2. **environment blocks automation:** wayland, sudo, display required
3. **blueprint explicitly deferred:** CI automation marked as deferred
4. **verification procedures exist:** verify_*.sh are manual, not automated
5. **human verification required:** path 5 (file picker) is inherently manual

the playtest has no acceptance test citations because this behavior cannot be verified via automated acceptance tests. the verification procedures (verify_*.sh) serve as the executable test suite, run manually by the foreman.

