# self review: has-journey-tests-from-repros (r5)

## fifth pass: question r4's "all covered" conclusion

r4 said "all journeys traced to implementation." but is that true? did I look at actual code?

---

## actual code inspection

### journey 1 step-by-step against tests/verify_isolation.sh

| step | expected (from repros) | actual code | line | match? |
|------|------------------------|-------------|------|--------|
| yama scope check | ptrace_scope=2 | `[[ "$scope" == "2" ]]` | ~59-67 | yes |
| ptrace blocked | strace fails EPERM | `grep -qi "operation not permitted\|EPERM"` | ~77-91 | yes |
| proc mem blocked | cat fails permission denied | `head -c 1 "/proc/$pid/mem"` fails | ~95-106 | yes |

### journey 2 step-by-step against tests/verify_isolation.sh

| step | expected (from repros) | actual code | line | match? |
|------|------------------------|-------------|------|--------|
| strace -p fails | "Operation not permitted" | same as above | ~77-91 | yes |
| cat /proc/pid/mem fails | "Permission denied" | same as above | ~95-106 | yes |

journey 2 is verified by the same tests as journey 1 — the "attacker" perspective is the same as the verification perspective.

---

## bdd structure inspection

repros uses given/when/then structure. does implementation match?

### repros journey 1 structure

```
given('[case1] fresh machine without isolation configured')
  when('[t0] before any changes')
  when('[t1] run configure_firefox_isolation')
  when('[t2] run configure_yama_ptrace')
  when('[t3] run verify_isolation')
```

### implementation structure

`tests/verify_isolation.sh` does not use explicit given/when/then keywords — it's bash, not jest. the **flow** however matches:

1. prereqs check (analogous to "given")
2. find firefox pid (setup)
3. run test_yama_scope (t3 first check)
4. run test_ptrace_blocked (t3 second check)
5. run test_proc_mem_blocked (t3 third check)

**does flow match?** yes — the test performs the same verification steps.

---

## critical paths inspection

| path | repros says | handoff coverage |
|------|-------------|------------------|
| apply isolation | run configure_* | handoff step 2 |
| verify isolation | run verify_isolation.sh | handoff step 4 |
| file picker | upload file | handoff step 5 |

**explicit handoff reference:** `5.3.verification.handoff.v1.to_foreman.md` contains all 5 steps.

---

## what could have gone wrong

| scenario | how I would have caught it | did I check? |
|----------|---------------------------|--------------|
| test file absent | glob for tests/*.sh | yes, both files exist |
| test checks wrong values | read actual assertions | yes, inspected grep patterns |
| flow doesn't match repros | compare structures | yes, compared step-by-step |
| critical path without handoff | read handoff document | yes, all 3 paths covered |

---

## why it holds

1. inspected actual code lines, not just file names
2. verified grep patterns match repros expected output
3. confirmed bdd flow matches (bash equivalent)
4. traced each critical path to handoff step
5. r4 conclusion stands after code inspection

the journeys from repros are implemented in test files.

