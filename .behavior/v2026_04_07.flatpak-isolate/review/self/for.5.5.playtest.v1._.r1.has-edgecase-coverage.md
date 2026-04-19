# self review: has-edgecase-coverage (r1)

## the question

are edge cases covered?
- what could go wrong?
- what inputs are unusual but valid?
- are boundaries tested?

---

## extant edge cases in playtest

the playtest documents 3 edge cases:

| edge | trigger | expected behavior |
|------|---------|-------------------|
| edge 1 | firefox not active | `[PREREQ]` message, exit 2 |
| edge 2 | firefox not installed | procedure skips, exit 0 |
| edge 3 | strace not installed | `[PREREQ]` message, exit 2 |

---

## what else could go wrong?

### configure_yama_ptrace issues

| scenario | likelihood | handled? |
|----------|------------|----------|
| no sudo access | medium | no — procedure will fail |
| sysctl.d dir absent | low | no — procedure will fail |
| ptrace_scope already 3 | low | no — procedure will overwrite |
| selinux blocks sysctl | low | platform specific |

**should we add edge case for no sudo?**

the playtest prerequisite says "sudo access available." if foreman lacks sudo, they can't run the configure procedure. this is a prerequisite failure, not an edge case.

**should we handle ptrace_scope=3?**

scope 3 is "no-attach" — more restrictive than 2. if someone has scope=3, overwrite to 2 weakens security.

**issue found:** the idempotent guard checks for scope=2, but doesn't check if scope is already higher.

let me check the actual code.

### configure_firefox_isolation issues

| scenario | likelihood | handled? |
|----------|------------|----------|
| firefox flatpak not installed | medium | yes — edge 2 |
| firefox snap installed | low | no — won't apply overrides |
| multiple firefox installs | low | no — only org.mozilla.firefox |
| flatpak command absent | low | no — procedure will fail |

**should we check for flatpak presence?**

if flatpak isn't installed, the `flatpak info` command fails. this is a prerequisite failure — the playtest prerequisites should include "flatpak installed."

**issue found:** prerequisites don't list "flatpak installed" but assume it via "firefox flatpak installed."

---

## what inputs are unusual but valid?

### multiple firefox instances

if user has multiple firefox windows/processes, `pgrep -f "firefox"` returns multiple PIDs. the verification procedure picks one.

**is this a problem?**

no — all firefox flatpak processes share the same namespace. if we can't ptrace one, we can't ptrace any.

### firefox via flatpak run vs desktop entry

| launch method | pid visible? |
|---------------|--------------|
| `flatpak run org.mozilla.firefox` | yes |
| desktop entry click | yes |
| dbus activation | maybe |

all methods should produce visible processes. this is not an edge case.

---

## are boundaries tested?

### boundary: flatpak vs native firefox

| firefox type | isolation works? |
|--------------|------------------|
| flatpak | yes — tested |
| native apt install | no — no flatpak isolation |
| snap | maybe — different sandbox |

the playtest only covers flatpak. this is correct per scope — the behavior is specifically about flatpak isolation.

### boundary: yama scope values

| scope | tested? |
|-------|---------|
| 0 (classic) | no — prerequisite: not configured |
| 1 (restricted) | no — verify would show different result |
| 2 (admin-only) | yes — happy path |
| 3 (no-attach) | no — more restrictive than target |

**issue:** verify_isolation.sh checks for scope=2 specifically. if scope=3, the test would fail even though isolation is stronger.

let me check the actual verify code.

---

## check verify_isolation.sh scope handle

```bash
test_yama_scope() {
  local scope
  scope=$(cat /proc/sys/kernel/yama/ptrace_scope)
  if [[ "$scope" -ge 2 ]]; then
    echo "[PASS] yama ptrace_scope = $scope (admin-only or higher)"
  else
    echo "[FAIL] yama ptrace_scope = $scope (expected >= 2)"
  fi
}
```

**wait** — I need to read the actual file to confirm this.

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| prerequisite gap | check prereqs vs what procedures need | yes — flatpak implicit |
| boundary not tested | enumerate boundary values | partial — scope 3 depends on code |
| unusual input not handled | list unusual but valid inputs | no — multiple PIDs ok |
| configure overwrites stricter | check guard logic | need to verify in code |

---

## issues to verify

1. does verify_isolation.sh accept scope >= 2?
2. does configure_yama_ptrace check if scope already higher?

I'll check these before I conclude.

---

## why it holds (awaited code verification)

the playtest covers the primary edge cases:
1. firefox not active
2. firefox not installed
3. strace not installed

additional edge cases are either:
- prerequisite failures (no sudo, no flatpak)
- outside scope (native firefox, snap)
- non-issues (multiple firefox processes)

the scope boundary (2 vs 3) needs code verification.

