# self review: has-zero-test-skips (r2)

## second pass: question the r1 conclusions

r1 said "no skips" — but did I look hard enough?

---

## skeptical re-examination

### question: is `|| true` a silent skip?

I see `|| true` in several places:

```bash
# verify_isolation.sh line 41
pid=$(pgrep -f "firefox.*flatpak" 2>/dev/null | head -1) || true

# verify_isolation.sh line 45
pid=$(flatpak ps 2>/dev/null | grep -i firefox | awk '{print $1}' | head -1) || true

# verify_isolation.sh line 77
output=$(strace -p "$pid" 2>&1 & sleep 0.5; kill $! 2>/dev/null) || true
```

**is this a skip?**

no. the `|| true` prevents `set -e` from exit early. the function then checks the result:
- line 48-52: if pid is empty, exits 2 (not a silent skip)
- line 79-86: checks output for expected error message

**verdict:** `|| true` is flow control, not a skip. the absence of a pid or expected output is checked afterward.

---

### question: does `2>/dev/null` hide failures?

I see `2>/dev/null` in several places:

```bash
# suppress stderr noise
output=$(strace -p "$pid" 2>&1 & sleep 0.5; kill $! 2>/dev/null) || true
```

**is this a skip?**

no. the `kill $!` sends signal to the strace background process. the `2>/dev/null` suppresses "no such process" errors if strace already exited. the actual strace output is captured to `$output` before the kill.

**verdict:** `2>/dev/null` on cleanup commands is not a skip.

---

### question: what if all tests pass because firefox isn't installed?

scenario: user runs `verify_wayland.sh` without firefox flatpak installed.

**what happens?**

the flatpak commands will fail with errors, and the tests will output [FAIL].

```bash
# verify_wayland.sh line 30
output=$(flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix 2>&1) || true
```

if firefox not installed, flatpak run fails with error. the grep for "no such file" might still match if the error says "error: org.mozilla.firefox not installed" — but that would be a false positive.

**is this a skip?**

partial concern. the test might pass for the wrong reason (error contains words that pass the check).

**verdict:** this is not a skip, but the test could have a false positive. the handoff document requires human to start firefox first, so this scenario is documented.

---

### question: is the firefox flatpak check in configure_firefox_isolation a skip?

```bash
if ! flatpak info org.mozilla.firefox &>/dev/null; then
  echo "• firefox flatpak not installed (skip)"
  return 0
fi
```

**is this a skip?**

yes, but it was documented as a divergence and backed up:
- the function cannot configure firefox if firefox is absent
- the message is explicit, not silent
- this is appropriate for optional prereq

**verdict:** documented divergence with backup rationale. not a silent skip.

---

## why it holds (r2 conclusion)

| potential skip | r1 verdict | r2 verdict | change? |
|----------------|------------|------------|---------|
| .skip() / .only() | n/a (bash) | n/a (bash) | no |
| `\|\| true` | flow control | flow control, checked after | no |
| `2>/dev/null` | suppresses noise | cleanup noise only | no |
| firefox flatpak check | documented divergence | documented divergence | no |
| firefox not installed in verify_wayland | not examined | possible false positive, but handoff requires firefox | new observation |

---

## what could have gone wrong

1. `|| true` could have been used to suppress real failures — but the code checks the result afterward
2. `2>/dev/null` could have hidden errors — but it's only on cleanup commands
3. tests could pass without firefox installed — but the handoff requires human to start firefox first

no silent skips found after deeper examination. r1 conclusion holds.

