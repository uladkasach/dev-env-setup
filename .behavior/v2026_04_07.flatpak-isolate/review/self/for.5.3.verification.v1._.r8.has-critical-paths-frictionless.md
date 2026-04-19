# self review: has-critical-paths-frictionless (r8)

## eighth pass: inspect actual code for friction

r7 analyzed paths conceptually. r8 inspects code line-by-line for hidden friction.

---

## path 1: configure_yama_ptrace

### code inspection

| line | code | potential friction |
|------|------|-------------------|
| 30 | `cat /proc/sys/kernel/yama/ptrace_scope` | none — always exists |
| 33-35 | idempotent guard | good — skips if already done |
| 42 | `sudo tee "$sysctl_file"` | **sudo prompt** — expected |
| 45 | `sudo sysctl --system > /dev/null` | silent reload — good |
| 48-54 | verify and report | clear feedback — good |

### hidden friction found?

**line 42:** uses `> /dev/null` which hides tee output. if tee fails, user sees no output before the subsequent error.

**is this a problem?** no — if sudo fails, the command fails visibly. the `/dev/null` hides the echoed content, not errors.

### verdict: no hidden friction

---

## path 2: configure_firefox_isolation

### code inspection

| line | code | potential friction |
|------|------|-------------------|
| 88-91 | firefox not installed check | good — clear skip message |
| 94 | check_portal_prereqs | **potential friction** — see below |
| 97-103 | idempotent guard | good — checks two markers |
| 108-114 | flatpak override | none — direct command |
| 116-126 | verbose success output | good — user sees what was done |

### check_portal_prereqs friction

**line 64-70:** warns if portal not found, but:
- warns and continues (doesn't fail)
- message is actionable ("install with: sudo apt install...")
- this is informational, not a blocker

**is this friction?** no — it's a helpful warn message, not a failure.

### hidden friction found?

**line 98-99:** idempotent guard checks for `nosocket=x11` AND `nofilesystem=home`. what if user partially applied overrides?

example: user runs flatpak override with just `--nosocket=x11` but not `--nofilesystem=home`. the guard would detect partial state and re-apply all overrides.

**is this a problem?** no — the `flatpak override` command is idempotent. re-apply is safe and ensures complete state.

### verdict: no hidden friction

---

## path 3: verify_isolation.sh

### code inspection

| line | code | potential friction |
|------|------|-------------------|
| 28-34 | check_prereqs for strace | good — clear instruction |
| 41-51 | find_firefox_pid | good — tries two methods |
| 77 | `strace -p "$pid" 2>&1 & sleep 0.5; kill $!` | **complex** — see below |

### strace command complexity

**line 77:** the strace command is complex:
1. runs strace in background
2. waits 0.5 seconds
3. kills the background process

**why complex?** strace attach either fails immediately (EPERM) or stalls if allowed. the sleep+kill ensures the test completes even if strace succeeds.

**is this friction for the user?** no — user sees `[PASS]` or `[FAIL]`, not the mechanics.

**could this fail unexpectedly?** if strace takes >0.5s to report error, output might be empty. but grep checks for error patterns, so empty output would be `[FAIL]`.

### verdict: no user-visible friction

---

## path 4: verify_wayland.sh

### code inspection

| line | code | potential friction |
|------|------|-------------------|
| 30 | `flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix` | **potential friction** — see below |
| 47 | `flatpak info --show-permissions` | none |
| 63 | `flatpak override --user --show` | none |

### flatpak run command

**line 30:** runs `ls /tmp/.X11-unix` inside firefox flatpak. this starts the flatpak runtime just to run ls.

**is this slow?** yes — flatpak run has startup overhead (~1-2s). but this is a one-time verification, not a daily operation.

**is this friction?** minor — user waits a few seconds. acceptable for verification procedure.

### verdict: minor delay, acceptable

---

## what could have gone wrong

| scenario | code location | found? |
|----------|---------------|--------|
| silent failure | tee > /dev/null | no — errors still visible |
| partial state | idempotent guards | no — re-apply is safe |
| stuck test | strace + sleep | no — timeout ensures completion |
| slow test | flatpak run ls | yes — minor, acceptable |

---

## why it holds

1. **configure_yama_ptrace:** sudo expected, errors visible, idempotent
2. **configure_firefox_isolation:** warn messages helpful, idempotent, verbose output
3. **verify_isolation.sh:** complex strace handled cleanly, clear results
4. **verify_wayland.sh:** minor startup delay, acceptable for verification

code inspection reveals no hidden friction beyond:
- sudo prompts (expected)
- chmod requirement (documented in handoff)
- flatpak startup delay (acceptable)

all friction is either expected, documented, or minor.

