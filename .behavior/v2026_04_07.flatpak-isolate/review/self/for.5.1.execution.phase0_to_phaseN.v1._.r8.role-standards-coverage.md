# self review: role-standards-coverage (r8)

## deeper reflection

r7 checked for adherance (violations). this review checks for *coverage* (omissions) — patterns that should be present but may have been forgotten.

the question: what *should* be here that *isn't*?

---

## brief directories enumerated

| directory | applies? | why |
|-----------|----------|-----|
| `practices/code.prod/pitofsuccess.errors/` | yes | bash procedures need error handle |
| `practices/code.prod/pitofsuccess.procedures/` | yes | procedures need idempotency |
| `practices/code.prod/evolvable.procedures/` | yes | procedures need single responsibility |
| `practices/code.prod/readable.comments/` | yes | functions need documentation |
| `practices/code.test/` | partially | manual test present, no unit test |
| `practices/lang.terms/` | yes | terms must avoid gerunds |
| `practices/lang.tones/` | yes | comments should be lowercase |
| `practices/work.flow/diagnose/` | maybe | test procedures help diagnose |
| `practices/code.prod/readable.narrative/` | maybe | bash has flow patterns |

---

## src/install_env.pt1.system.security.sh — coverage analysis

### expected patterns

| pattern | source rule | present? | where |
|---------|-------------|----------|-------|
| failfast mode | rule.require.failfast | yes | `set -euo pipefail` line 17 |
| idempotent guards | rule.require.idempotent-procedures | yes | lines 33-36, 97-102 |
| what-why headers | rule.require.what-why-headers | yes | lines 19-27, 57-62, 73-82 |
| verification after mutation | rule.forbid.failhide | yes | lines 48-54 |
| prereq validation | rule.forbid.failhide | yes | lines 63-71 |
| single purpose per function | rule.require.single-responsibility | yes | 3 functions |
| lowercase comments | rule.prefer.lowercase | yes | all comments |
| no gerunds | rule.forbid.gerunds | yes | checked in r7 |

### possibly absent patterns

| pattern | source rule | assessment |
|---------|-------------|------------|
| input validation | rule.require.failfast | not needed — functions take no args |
| trap cleanup | rule.prefer.* | not needed — no temp files created |
| shellcheck directive | - | nice-to-have, not required |
| version check | - | not applicable — system tools |

**why input validation is not absent:**
- `configure_yama_ptrace()` takes no arguments
- `configure_firefox_isolation()` takes no arguments
- `check_portal_prereqs()` takes no arguments

no user input → no input validation needed.

**why trap cleanup is not absent:**
- no temp files created
- no background processes spawned
- no resources to clean up

---

## tests/verify_isolation.sh — coverage analysis

### expected patterns

| pattern | source rule | present? | where |
|---------|-------------|----------|-------|
| semantic exit codes | rule.require.exit-code-semantics | yes | 0, 1, 2 |
| prereq check | rule.require.failfast | yes | lines 27-34 |
| actionable error messages | rule.require.failloud | yes | lines 30-31 |
| pass/fail summary | - | yes | lines 105-115 |
| timeout for hang-prone commands | rule.forbid.failhide | yes | line 77 |

### possibly absent patterns

| pattern | source rule | assessment |
|---------|-------------|------------|
| verbose mode flag | - | not needed — output is already clear |
| color output | - | nice-to-have, not required |
| json output mode | - | not applicable — human verification |
| cleanup on interrupt | - | not needed — no state to clean |

**why timeout is present and not absent:**
the strace command can hang indefinitely if it successfully attaches. the pattern:
```bash
output=$(strace -p "$pid" 2>&1 & sleep 0.5; kill $! 2>/dev/null) || true
```
runs strace in background, waits 0.5 seconds, then kills it. this prevents the test from a permanent hang.

if this pattern were absent, `./verify_isolation.sh` would hang forever when isolation is *not* configured.

---

## tests/verify_wayland.sh — coverage analysis

### expected patterns

| pattern | source rule | present? | where |
|---------|-------------|----------|-------|
| semantic exit codes | rule.require.exit-code-semantics | yes | 0, 1, 2 |
| pass/fail summary | - | yes | lines 86-96 |
| sandbox-aware check | - | yes | `flatpak run --command=ls` line 30 |
| override verification | - | yes | lines 60-83 |

### possibly absent patterns

| pattern | source rule | assessment |
|---------|-------------|------------|
| firefox prereq check | rule.require.failfast | **candidate** |

**issue found:** `verify_wayland.sh` does not explicitly check if firefox flatpak is installed before tests run. if firefox is not installed, `flatpak run --command=ls org.mozilla.firefox ...` will fail.

**assessment:** this is acceptable because:
1. the error message from flatpak is clear: "error: org.mozilla.firefox not installed"
2. the test will fail with exit 1, not silently pass
3. a prereq check would be redundant with flatpak's own error

**conclusion:** not a gap — flatpak provides adequate error message.

---

## test coverage assessment

### what should exist

| test type | exists? | assessment |
|-----------|---------|------------|
| manual isolation test | yes | verify_isolation.sh |
| manual wayland test | yes | verify_wayland.sh |
| unit test for bash functions | no | acceptable — repo has no bash test framework |
| CI integration test | no | acceptable — requires wayland compositor |
| dbus verification test | no | acceptable — explicitly deferred per blueprint |

**why unit tests are not absent:**
1. this repo does not use a bash test framework (bats, shunit2)
2. the functions are idempotent and can be re-run manually
3. the verification procedures *are* the tests

**why CI tests are not absent:**
1. documented in blueprint: "automated CI is blocked — no wayland compositor available in CI environments"
2. the tests require actual ptrace and flatpak sandbox behavior
3. mocks would not verify real isolation

---

## edge case coverage

### edge cases that are handled

| edge case | handled by | how |
|-----------|------------|-----|
| firefox flatpak not installed | configure_firefox_isolation | early return with message |
| yama already configured | configure_yama_ptrace | idempotent guard |
| strace not installed | verify_isolation.sh | prereq check with exit 2 |
| firefox flatpak not active | verify_isolation.sh | prereq check with exit 2 |
| flatpak override already applied | configure_firefox_isolation | marker check |

### edge cases that are not handled (acceptable)

| edge case | why acceptable |
|-----------|----------------|
| sudo not available | flatpak override uses --user (no sudo needed) |
| multiple firefox pids | `head -1` takes first match — acceptable |
| x11-only system | out of scope — cosmic uses wayland |

---

## summary

| file | patterns expected | patterns present | gaps |
|------|-------------------|------------------|------|
| install_env.pt1.system.security.sh | 8 | 8 | 0 |
| tests/verify_isolation.sh | 5 | 5 | 0 |
| tests/verify_wayland.sh | 4 | 4 | 0 |

**findings:**
- all required mechanic role patterns are present
- optional patterns (trap cleanup, color output, verbose mode) are not needed for this scope
- test coverage is appropriate — manual verification is the correct approach
- no omissions found

