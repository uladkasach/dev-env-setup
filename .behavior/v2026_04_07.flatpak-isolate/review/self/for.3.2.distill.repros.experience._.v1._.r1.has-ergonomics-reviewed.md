# self review: has-ergonomics-reviewed

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.2.distill.repros.experience._.v1.i1.md`

---

## input/output ergonomics review

### journey 1: apply isolation

#### input

```bash
source src/install_env.pt1.system.security.sh && configure_firefox_isolation
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — standard pattern in this repo |
| can we simplify? | **no** — already minimal (source + call) |
| friction? | **none** — matches extant patterns |

#### output

```
• firefox flatpak overrides applied
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — matches extant echo patterns |
| could be clearer? | **maybe** — could list which overrides applied |
| friction? | **none** |

**verdict**: input/output ergonomics hold. no changes needed.

---

### journey 2: verify isolation

#### input

```bash
./tests/verify_isolation.sh
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — single command, no args |
| can we simplify? | **no** — already minimal |
| friction? | **none** |

#### output

```
=== flatpak isolation verification ===
[INFO] firefox pid: 12345
[TEST] yama ptrace_scope...
[PASS] ptrace_scope=2 (admin-only)
[TEST] ptrace attach...
[PASS] ptrace blocked
[TEST] /proc/pid/mem read...
[PASS] proc mem blocked
=== results: 3 passed, 0 failed ===
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — clear pass/fail, test-by-test |
| could be clearer? | **no** — format is scannable |
| friction? | **none** |

**verdict**: input/output ergonomics hold. output is scannable and actionable.

---

### journey 3: attacker attempt fails

#### input

```bash
strace -p $FIREFOX_PID
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **n/a** — attacker perspective, not user |

#### output

```
strace: attach: ptrace(PTRACE_SEIZE, 12345): Operation not permitted
```

| criterion | assessment |
|-----------|------------|
| feels natural? | **yes** — standard kernel error message |

**verdict**: attacker experience is intentionally hostile. no changes needed.

---

## pit of success review

| criterion | assessment |
|-----------|------------|
| intuitive design | **holds** — users familiar with bash procedures succeed without docs |
| convenient | **holds** — no required inputs for most operations |
| expressive | **holds** — procedure names describe intent |
| composable | **holds** — procedures can be chained with && |
| lower trust contracts | **holds** — verification checks actual system state |
| deeper behavior | **holds** — idempotent guards handle re-runs |

---

## friction points identified

| friction | severity | resolution |
|----------|----------|------------|
| must remember to source before call | low | matches repo conventions |
| must have firefox active for verification | inherent | skip message clarifies |
| verification output could be JSON | nice-to-have | defer — human readability preferred |

---

## issues found

**no blocker issues.**

minor observation: could add JSON output mode for verification (--json flag) for machine consumption. but human-readable output is the priority for this use case. defer to future if needed.

---

## verdict

input/output ergonomics are natural and follow repo conventions. no changes needed.

