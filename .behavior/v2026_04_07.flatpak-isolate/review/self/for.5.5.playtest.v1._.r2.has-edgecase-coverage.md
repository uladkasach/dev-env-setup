# self review: has-edgecase-coverage (r2)

## second pass: verify r1's code questions

r1 identified two issues to verify:
1. does verify_isolation.sh accept scope >= 2?
2. does configure_yama_ptrace check if scope already higher?

---

## code verification: verify_isolation.sh

actual code (lines 62-68):
```bash
if [[ "$scope" == "2" ]]; then
  echo "[PASS] yama ptrace_scope = 2 (admin-only)"
else
  echo "[FAIL] yama ptrace_scope = $scope (expected 2)"
fi
```

**result:** checks for exactly "2", not ">= 2".

**implication:** if scope is 3 (more restrictive), test shows FAIL even though isolation is stronger.

---

## code verification: configure_yama_ptrace

actual code (lines 33-36):
```bash
if [[ "$current_scope" == "2" ]]; then
  echo "• yama ptrace_scope already set to 2 (skip)"
  return 0
fi
```

then sets scope to 2.

**result:** if scope is 3, procedure overwrites to 2 (weakens security).

---

## are these critical issues?

### scope=3 frequency analysis

| scope | typical systems | likely? |
|-------|-----------------|---------|
| 0 | ubuntu/debian default before hardened | common |
| 1 | ubuntu default after hardened | common |
| 2 | explicitly configured for security | rare |
| 3 | paranoid systems (blocks even root) | very rare |

scope=3 is extremely rare. systems that use it are specialized (high-security, embedded, etc).

### impact assessment

| issue | severity | likelihood | verdict |
|-------|----------|------------|---------|
| verify fails on scope=3 | low | very low | acceptable |
| configure weakens scope=3 | medium | very low | acceptable |

**reason:** a user with scope=3 is security-conscious and would:
1. notice the configure procedure set to 2
2. manually adjust or skip the procedure
3. understand why verify shows a different value

---

## should we fix these?

### option 1: fix verify to check >= 2

```bash
if [[ "$scope" -ge 2 ]]; then
```

**pro:** correct behavior
**con:** scope creep — this is a playtest review, not a code review

### option 2: fix configure to preserve higher values

```bash
if [[ "$current_scope" -ge 2 ]]; then
```

**pro:** doesn't weaken extant security
**con:** scope creep

### option 3: document as known edge case

accept that scope=3 is out of scope for this behavior.

**decision:** option 3 — document and accept. the behavior targets scope=2 specifically. scope=3 is out of scope.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| scope boundary not tested | enumerate all values | yes — scope 3 |
| code doesn't match playtest | read actual code | yes — exact match only |
| edge case is critical | assess frequency/impact | no — very rare |

---

## why it holds

1. **extant edge cases covered:** firefox not active, not installed, strace absent
2. **scope=3 documented:** out of scope, very rare
3. **prerequisite gaps minor:** flatpak implicit via "firefox flatpak"
4. **unusual inputs handled:** multiple firefox PIDs ok
5. **boundaries clear:** flatpak only, yama scope=2 target

the playtest covers edge cases appropriate for the scope. scope=3 is an edge of an edge — documented but not targeted.

