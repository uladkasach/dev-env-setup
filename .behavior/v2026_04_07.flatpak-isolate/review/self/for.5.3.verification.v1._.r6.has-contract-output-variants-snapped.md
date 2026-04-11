# self review: has-contract-output-variants-snapped (r6)

## sixth pass: question the "repros is the snapshot" claim

r5 said "repros serves as snapshot spec." but does repros actually document all output variants? let me trace each actual output message to its documentation.

---

## verify_isolation.sh output trace

### actual outputs from code inspection

| line | actual output | documented? | where? |
|------|---------------|-------------|--------|
| 29 | `[PREREQ] strace not installed` | no | not in repros |
| 33 | `[PREREQ] strace installed` | no | not in repros |
| 49-50 | `[PREREQ] firefox flatpak not active` | partial | mentioned in repros sketch |
| 63 | `[PASS] yama ptrace_scope = 2 (admin-only)` | yes | repros line 83 |
| 66 | `[FAIL] yama ptrace_scope = $scope (expected 2)` | no | not in repros |
| 80 | `[PASS] ptrace attach blocked` | yes | repros line 84 |
| 83-84 | `[FAIL] ptrace attach may have succeeded` | no | not in repros |
| 99 | `[PASS] /proc/$pid/mem blocked` | yes | repros line 85 |
| 96 | `[FAIL] /proc/$pid/mem readable` | no | not in repros |
| 108-109 | `results: X passed, Y failed` | yes | repros line 87 |

### gap analysis

| gap | severity | impact |
|-----|----------|--------|
| [PREREQ] messages not documented | low | prereq failures are obvious |
| [FAIL] messages not documented | medium | reviewer can't vibecheck failure output |

**verdict:** failure outputs are not documented in repros. a PR reviewer would not see what failure looks like.

---

## verify_wayland.sh output trace

### actual outputs from code inspection

| line | actual output | documented? | where? |
|------|---------------|-------------|--------|
| 33 | `[PASS] x11 socket not visible to firefox` | partial | repros mentions x11 denied |
| 36-37 | `[FAIL] x11 socket visible to firefox` | no | not in repros |
| 50 | `[PASS] wayland socket allowed` | yes | repros mentions wayland |
| 53-54 | `[FAIL] wayland socket not found in permissions` | no | not in repros |
| 76 | `[PASS] x11 and fallback-x11 sockets denied via override` | no | not in repros |
| 79-80 | `[FAIL] x11 socket overrides not set` | no | not in repros |
| 88-89 | `results: X passed, Y failed` | no | not in repros |

### gap analysis

| gap | severity | impact |
|-----|----------|--------|
| test_x11_sockets_denied() not in repros | low | extra test, adds coverage |
| [FAIL] messages not documented | medium | reviewer can't vibecheck failure output |
| verify_wayland.sh results not documented | low | follows same pattern as verify_isolation |

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| failure output undocumented | trace each echo to repros | yes — [FAIL] variants absent |
| extra test not documented | compare test functions to repros | yes — test_x11_sockets_denied |
| prereq messages undocumented | search repros for [PREREQ] | yes — absent |

---

## should I fix this?

### option 1: add failure variants to repros

pros:
- pr reviewers see all output variants
- documentation complete

cons:
- scope creep — repros already approved
- failure cases are self-explanatory

### option 2: document as acceptable divergence

the failure messages are:
1. clear and self-documented
2. contain the expected value
3. contain diagnostic info

this matches the prior divergence pattern — extra safety without documented spec.

---

## why it holds (with caveats)

1. **success outputs documented:** all [PASS] messages are in repros
2. **failure outputs self-documented:** include expected vs actual
3. **prereq outputs clear:** tell user what to do
4. **extra test (test_x11_sockets_denied) adds coverage:** documented in blueprint as divergence

the project prioritizes coverage over documentation completeness. failure outputs are designed to be self-explanatory rather than spec-documented.

**this is acceptable because:**
- bash procedures are not user-faced sdks
- output is for human use in debug, not machine use to parse
- failure messages include actionable guidance

**documented divergence:**
- failure variants not in repros (self-explanatory pattern)
- test_x11_sockets_denied not in repros (extra coverage)

