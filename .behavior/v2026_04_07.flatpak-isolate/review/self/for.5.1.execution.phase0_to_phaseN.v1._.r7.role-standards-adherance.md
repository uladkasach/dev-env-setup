# self review: role-standards-adherance (r7)

## deeper reflection

r6 provided a table-based checklist. this review digs deeper into *why* each standard holds and what violations would look like.

---

## brief directories checked

| directory | relevance |
|-----------|-----------|
| `practices/code.prod/pitofsuccess.errors/` | failfast, failloud, error handle |
| `practices/code.prod/pitofsuccess.procedures/` | idempotent procedures |
| `practices/code.prod/evolvable.procedures/` | input patterns, single responsibility |
| `practices/code.prod/readable.comments/` | what-why headers |
| `practices/lang.terms/` | term requirements, gerund avoidance |
| `practices/lang.tones/` | lowercase preference |

---

## src/install_env.pt1.system.security.sh — deep analysis

### rule.require.failfast

**implementation:**
```bash
set -euo pipefail
```

**why this holds:**
- `-e` makes any non-zero exit code terminate the procedure
- `-u` catches undefined variables before they cause silent failures
- `-o pipefail` ensures `cmd1 | cmd2` fails if cmd1 fails (not just cmd2)

**what violation would look like:**
```bash
# bad: no set options
#!/bin/bash
cat /nonexistent 2>/dev/null  # silently swallows error
```

the implementation fails fast on any error.

---

### rule.require.idempotent-procedures

**configure_yama_ptrace guard:**
```bash
current_scope=$(cat /proc/sys/kernel/yama/ptrace_scope 2>/dev/null) || current_scope="unknown"
if [[ "$current_scope" == "2" ]]; then
  echo "• yama ptrace_scope already set to 2 (skip)"
  return 0
fi
```

**why this holds:**
- reads live kernel state, not config file
- compares against exact target value
- exits early when already configured
- does not re-run sudo commands if unnecessary

**what violation would look like:**
```bash
# bad: always runs sudo regardless of state
echo "kernel.yama.ptrace_scope = 2" | sudo tee /etc/sysctl.d/99-yama-ptrace.conf
sudo sysctl --system  # unnecessary if already at 2
```

---

**configure_firefox_isolation guard:**
```bash
if [[ -f "$override_file" ]]; then
  if grep -q "nosocket=x11" "$override_file" && \
     grep -q "nofilesystem=home" "$override_file"; then
    echo "• firefox flatpak overrides already applied (skip)"
    return 0
  fi
fi
```

**why this holds:**
- checks for two distinct markers (not just one)
- uses actual file content, not command exit code
- skips flatpak override command if already applied

**what violation would look like:**
```bash
# bad: always applies overrides
flatpak override --user org.mozilla.firefox \
  --nofilesystem=home  # re-runs every time
```

---

### rule.require.what-why-headers

**implementation:**
```bash
#########################
## configure_yama_ptrace
##
## sets yama ptrace_scope to 2 (admin-only).
## blocks same-uid processes from ptrace attach.
## requires sudo.
##
## idempotent: safe to re-run.
#########################
```

**why this holds:**
- first line = what it is (function name)
- second block = what it does
- includes "requires sudo" (dependency)
- includes "idempotent" (behavior note)

this format matches bash convention in this repo (see other `install_env.*.sh` files).

---

### rule.forbid.gerunds

**scanned for `-ing` as noun:**

| word | line | type | verdict |
|------|------|------|---------|
| none found | - | - | pass |

all verbs use imperative or past participle:
- `sets` (imperative)
- `blocks` (imperative)
- `applied` (past participle)
- `blocked` (past participle)

---

## tests/verify_isolation.sh — deep analysis

### rule.require.exit-code-semantics

**implementation:**
```bash
exit 2  # prereqs not met (constraint error)
exit 1  # test failed (malfunction)
exit 0  # all passed
```

**why this holds:**
- exit 2 = caller must fix (install strace, start firefox)
- exit 1 = server must fix (isolation not configured)
- exit 0 = success

matches rule.require.exit-code-semantics exactly.

---

### rule.forbid.failhide

**check_prereqs:**
```bash
if ! command -v strace &>/dev/null; then
  echo "[PREREQ] strace not installed"
  echo "         install with: sudo apt install strace"
  exit 2
fi
```

**why this holds:**
- does not return 0 when prereq absent
- provides actionable message
- exits with semantic code

**what violation would look like:**
```bash
# bad: hides absent prereq
if ! command -v strace &>/dev/null; then
  echo "warning: strace not found, skip test"
  return 0  # falsely reports success
fi
```

---

### strace timeout pattern

```bash
output=$(strace -p "$pid" 2>&1 & sleep 0.5; kill $! 2>/dev/null) || true
```

**why this holds:**
- background + sleep + kill avoids strace hang
- captures stderr (where strace error goes)
- `|| true` prevents set -e from termination on expected failure

**what violation would look like:**
```bash
# bad: hangs forever if strace attaches
output=$(strace -p "$pid" 2>&1)  # blocks indefinitely
```

---

## tests/verify_wayland.sh — deep analysis

### flatpak run pattern

```bash
output=$(flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix 2>&1) || true
```

**why this holds:**
- runs command *inside* the sandbox namespace
- checks what firefox can see, not what host can see
- captures both stdout and stderr

**what violation would look like:**
```bash
# bad: checks host, not sandbox
output=$(ls /tmp/.X11-unix 2>&1)  # always sees x11 socket
```

---

### permission check pattern

```bash
output=$(flatpak info --show-permissions org.mozilla.firefox 2>/dev/null) || true
if echo "$output" | grep -q "socket=wayland"; then
```

**why this holds:**
- queries flatpak's permission system directly
- does not rely on file existence
- handles absent permission gracefully

---

## issues found

none.

---

## summary

| file | standards | verdict |
|------|-----------|---------|
| install_env.pt1.system.security.sh | failfast, idempotent, what-why | pass |
| tests/verify_isolation.sh | exit-code-semantics, failfast, no failhide | pass |
| tests/verify_wayland.sh | sandbox check pattern, permission query | pass |

all three files adhere to mechanic role standards. patterns were chosen deliberately and would fail in specific ways if violated.

