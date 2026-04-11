# self review: has-ergonomics-validated (r8)

## eighth pass: compare repros plan to implementation

the question: did implementation match what repros planned?

---

## configure_yama_ptrace

### repros planned (line 68-72)

```bash
$ configure_yama_ptrace

• yama ptrace_scope set to 2 (admin-only)
```

### implementation actual (line 38, 50-51)

```bash
• set yama ptrace_scope to 2 (admin-only)
  ✓ ptrace_scope now 2
```

### comparison

| aspect | repros | actual | match? |
|--------|--------|--------|--------|
| prefix | `•` | `•` | yes |
| message | "yama ptrace_scope set to 2" | "set yama ptrace_scope to 2" | **drift** |
| confirmation | none | `✓ ptrace_scope now 2` | **addition** |

### is the drift acceptable?

- message reorder is minor (verb moved to front)
- confirmation line is an improvement (explicit verification)

**verdict:** acceptable drift — implementation is more informative.

---

## configure_firefox_isolation

### repros planned (line 61-63)

```bash
$ source src/install_env.pt1.system.security.sh && configure_firefox_isolation

• firefox flatpak overrides applied
```

### implementation actual (line 105, 116-126)

```bash
• apply firefox flatpak isolation overrides
  ✓ overrides applied

  applied flags:
    --nofilesystem=home
    --nofilesystem=host
    --nosocket=x11
    --nosocket=fallback-x11
    --socket=wayland
    --no-talk-name=org.freedesktop.secrets

  verify with: flatpak override --user --show org.mozilla.firefox
```

### comparison

| aspect | repros | actual | match? |
|--------|--------|--------|--------|
| prefix | `•` | `•` | yes |
| message | "overrides applied" | "apply...overrides" + "✓ overrides applied" | **drift** |
| detail | none | full flag list | **addition** |
| verify hint | none | "verify with: ..." | **addition** |

### is the drift acceptable?

- implementation is more verbose but more helpful
- user sees exactly what flags were set
- user gets verify command for manual check

**verdict:** acceptable drift — implementation is more informative.

---

## verify_isolation.sh

### repros planned (line 76-88)

```bash
$ ./tests/verify_isolation.sh

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

### implementation actual

```bash
verify_isolation: check host-to-sandbox isolation

[PREREQ] strace installed

find firefox flatpak pid...
found firefox pid: 12345

[PASS] yama ptrace_scope = 2 (admin-only)
[PASS] ptrace attach blocked
[PASS] /proc/$pid/mem blocked

==========================================
results: 3 passed, 0 failed
==========================================
```

### comparison

| aspect | repros | actual | match? |
|--------|--------|--------|--------|
| header | `=== flatpak isolation verification ===` | `verify_isolation: check host-to-sandbox isolation` | **drift** |
| [INFO] tag | `[INFO]` | no tag | **removal** |
| [TEST] tag | `[TEST]` | no tag | **removal** |
| [PASS] format | `ptrace_scope=2` | `yama ptrace_scope = 2` | **drift** |
| results format | `=== results ===` | `===` line + text | **drift** |

### is the drift acceptable?

- tag removal: simpler output, less visual noise
- format drift: minor text differences
- core semantics preserved: PASS/FAIL with explanations

**verdict:** acceptable drift — output is cleaner and simpler.

---

## verify_wayland.sh

### repros planned

no explicit plan in repros for verify_wayland.sh output.

### implementation actual

```bash
verify_wayland: check wayland isolation

[PASS] x11 socket not visible to firefox
[PASS] wayland socket allowed
[PASS] x11 and fallback-x11 sockets denied via override

==========================================
results: 3 passed, 0 failed
==========================================
```

### comparison

no repros plan to compare against. this is acceptable because:
- verify_wayland.sh was added as extra coverage beyond repros
- output follows same pattern as verify_isolation.sh (peer procedure)

**verdict:** n/a — not planned in repros, but consistent with peer procedure.

---

## what could have gone wrong

| scenario | how I would detect it | found? |
|----------|----------------------|--------|
| output worse than planned | compare verbosity, clarity | no — output is better |
| user confused by output | check for clear PASS/FAIL | no — results clear |
| input changed from plan | compare invocation style | no — same `source && call` pattern |

---

## why it holds

1. **configure_yama_ptrace:** drift adds confirmation line — improvement
2. **configure_firefox_isolation:** drift adds flag list and verify hint — improvement
3. **verify_isolation.sh:** drift removes tags, simplifies — acceptable
4. **verify_wayland.sh:** not in repros — follows peer pattern

all drift is toward **more informative output** or **cleaner format**. no regressions found.

