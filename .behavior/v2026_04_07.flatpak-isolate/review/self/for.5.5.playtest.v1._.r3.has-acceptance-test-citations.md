# self review: has-acceptance-test-citations (r3)

## third pass: question the review sequence

r1 and r2 were skipped (jumped to r4). let me create proper continuity.

r1 established: no acceptance tests exist, all steps untestable.
r2 questioned: paths 1-2 could be automated but effort/risk too high.

now r3: what did r1-r2 miss?

---

## re-examine: did we check all test locations?

r1 only looked in `tests/`. where else might tests live?

| location | checked? | result |
|----------|----------|--------|
| tests/ | yes | verify_*.sh only |
| src/*.test.sh | no | let me check |
| .github/workflows/ | no | let me check |

### check for other test files

```
ls src/*.test.sh 2>/dev/null
# no matches

ls .github/workflows/*.yml 2>/dev/null
# no workflow files (no CI setup)
```

**confirmed:** no other test locations. the project has no CI.

---

## re-examine: is "no CI" intentional?

this repo is `dev-env-setup` — a personal configuration repo. it configures a local machine.

### what would CI even test?

| aspect | can CI test? |
|--------|-------------|
| bash syntax | yes — shellcheck |
| idempotency | no — needs real system |
| security config | no — needs kernel access |
| flatpak overrides | no — needs flatpak runtime |

**insight:** CI could only test syntax. the meaningful tests require the actual machine.

---

## re-examine: does the playtest serve as acceptance test?

### what is the playtest?

the playtest is a document that tells the foreman:
1. what steps to run
2. what outcomes to expect
3. when to declare pass/fail

### does this match acceptance test purpose?

| acceptance test property | playtest has it? |
|--------------------------|------------------|
| verifies user-observable behavior | yes |
| has pass/fail criteria | yes |
| exercises the system end-to-end | yes |
| automated | **no** |
| repeatable | yes |

**the playtest IS an acceptance test — just not automated.**

---

## update mental model

the guide asks to "cite the acceptance test for each playtest step."

but the playtest **IS** the acceptance test. the verification procedures (verify_*.sh) are the executable portion.

| playtest path | executable test |
|---------------|-----------------|
| path 1 | configure output (self-verifies) |
| path 2 | configure output (self-verifies) |
| path 3 | verify_isolation.sh |
| path 4 | verify_wayland.sh |
| path 5 | human observation |

the "acceptance test citations" are the verification procedures referenced in the playtest.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| tests exist elsewhere | check all dirs | no — tests/ only |
| CI could test more | enumerate CI-able items | partial — shellcheck only |
| playtest isn't acceptance test | compare properties | no — it is |

---

## why it holds

1. **no automated acceptance tests:** verified by dir search
2. **CI not set up:** no .github/workflows/
3. **CI could only test syntax:** meaningful tests need machine
4. **playtest IS the acceptance test:** manual execution format
5. **verification procedures are citations:** verify_*.sh referenced in playtest

the "acceptance test citations" for this playtest are:
- `tests/verify_isolation.sh` for path 3
- `tests/verify_wayland.sh` for path 4
- configure procedure output for paths 1-2
- human observation for path 5

the playtest and its verification procedures together form the acceptance test suite.

