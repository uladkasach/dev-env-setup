# self review: behavior-declaration-adherance (r5)

## artifact reviewed

- `src/install_env.pt1.system.security.sh`
- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`

checked against:
- `1.vision.md` (vision)
- `2.1.criteria.blackbox.md` (criteria)
- `3.3.1.blueprint.product.v1.i1.md` (blueprint)

---

## configure_yama_ptrace() adherance

### blueprint spec

```
configure_yama_ptrace()
├─ idempotent guard
│  └─ check /proc/sys/kernel/yama/ptrace_scope
├─ write_sysctl_conf()
│  └─ write /etc/sysctl.d/99-yama-ptrace.conf
├─ reload_sysctl()
│  └─ sudo sysctl --system
└─ echo progress
```

### implementation check

| spec | code | match? |
|------|------|--------|
| idempotent guard | `if [[ "$current_scope" == "2" ]]; then ... return 0` | yes |
| check ptrace_scope | `cat /proc/sys/kernel/yama/ptrace_scope` | yes |
| write to sysctl.d | `echo ... \| sudo tee /etc/sysctl.d/99-yama-ptrace.conf` | yes |
| reload sysctl | `sudo sysctl --system` | yes |
| echo progress | `echo "• set yama ptrace_scope to 2 (admin-only)"` | yes |

**adherance**: exact match.

---

## configure_firefox_isolation() adherance

### blueprint spec

```
configure_firefox_isolation()
├─ check_portal_prereqs()
│  └─ verify xdg-desktop-portal installed, warn if not
├─ idempotent guard
│  └─ grep flatpak override --show for marker
├─ apply_flatpak_overrides()
│  └─ flatpak override --user org.mozilla.firefox \
│       --nofilesystem=home --nofilesystem=host \
│       --nosocket=x11 --nosocket=fallback-x11 \
│       --socket=wayland \
│       --no-talk-name=org.freedesktop.secrets
└─ echo progress
```

### implementation check

| spec | code | match? |
|------|------|--------|
| check_portal_prereqs() | calls `check_portal_prereqs` at line 94 | yes |
| portal check logic | checks /usr/libexec/xdg-desktop-portal + flatpak info | yes |
| idempotent guard | `grep -q "nosocket=x11" && grep -q "nofilesystem=home"` | yes |
| --nofilesystem=home | line 109 | yes |
| --nofilesystem=host | line 110 | yes |
| --nosocket=x11 | line 111 | yes |
| --nosocket=fallback-x11 | line 112 | yes |
| --socket=wayland | line 113 | yes |
| --no-talk-name=org.freedesktop.secrets | line 114 | yes |
| echo progress | line 105: "• apply firefox flatpak isolation overrides" | yes |

**adherance**: exact match.

---

## tests/verify_isolation.sh adherance

### blueprint spec

```
verify_isolation.sh
├─ main()
│  ├─ check_prereqs()
│  │  └─ verify strace installed, exit with instructions if not
│  ├─ find_firefox_pid()
│  │  ├─ pgrep -f "firefox.*flatpak"
│  │  └─ fallback: flatpak ps | grep firefox
│  │
│  ├─ test_yama_scope()
│  │  ├─ read /proc/sys/kernel/yama/ptrace_scope
│  │  ├─ expect: 2 (admin-only)
│  │  └─ output: [PASS] or [FAIL]
│  │
│  ├─ test_ptrace_blocked()
│  │  ├─ strace -p $FIREFOX_PID
│  │  ├─ expect: "Operation not permitted"
│  │  └─ output: [PASS] or [FAIL]
│  │
│  ├─ test_proc_mem_blocked()
│  │  ├─ head -c 1 /proc/$FIREFOX_PID/mem
│  │  ├─ expect: EPERM or ENOENT
│  │  └─ output: [PASS] or [FAIL]
│  │
│  └─ report_results()
│     ├─ tally pass/fail
│     └─ exit code: 0=all pass, 1=any fail
```

### implementation check

| spec | code | match? |
|------|------|--------|
| check_prereqs() | line 27 | yes |
| strace check | `command -v strace` | yes |
| exit instructions | "install with: sudo apt install strace" | yes |
| find_firefox_pid() | line 37 | yes |
| pgrep pattern | `pgrep -f "firefox.*flatpak"` | yes |
| flatpak ps fallback | `flatpak ps ... \| grep -i firefox` | yes |
| test_yama_scope() | line 58 | yes |
| read scope | `cat /proc/sys/kernel/yama/ptrace_scope` | yes |
| expect 2 | `[[ "$scope" == "2" ]]` | yes |
| [PASS]/[FAIL] output | lines 63, 66 | yes |
| test_ptrace_blocked() | line 72 | yes |
| strace -p | `strace -p "$pid"` | yes |
| expect "Operation not permitted" | `grep -qi "operation not permitted\|EPERM"` | yes |
| test_proc_mem_blocked() | line 90 | yes |
| head -c 1 | `head -c 1 "/proc/$pid/mem"` | yes |
| report_results() | line 105 | yes |
| exit code 0/1 | lines 112-114 | yes |

**adherance**: exact match.

---

## tests/verify_wayland.sh adherance

### blueprint spec

```
verify_wayland.sh
├─ main()
│  ├─ test_x11_socket_denied()
│  │  ├─ flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix
│  │  ├─ expect: empty or "No such file"
│  │  └─ output: [PASS] or [FAIL]
│  │
│  ├─ test_wayland_socket_allowed()
│  │  ├─ flatpak info --show-permissions org.mozilla.firefox
│  │  ├─ expect: "socket=wayland"
│  │  └─ output: [PASS] or [FAIL]
│  │
│  └─ report_results()
│     └─ exit code: 0=all pass, 1=any fail
```

### implementation check

| spec | code | match? |
|------|------|--------|
| test_x11_socket_denied() | line 26 | yes |
| flatpak run --command=ls | `flatpak run --command=ls org.mozilla.firefox /tmp/.X11-unix` | yes |
| expect empty/"No such file" | `grep -qi "no such file\|cannot access"` | yes |
| [PASS]/[FAIL] output | lines 33, 36 | yes |
| test_wayland_socket_allowed() | line 43 | yes |
| flatpak info --show-permissions | `flatpak info --show-permissions org.mozilla.firefox` | yes |
| expect "socket=wayland" | `grep -q "socket=wayland"` | yes |
| report_results() | line 86 | yes |
| exit code 0/1 | lines 92-95 | yes |

**extra function**: test_x11_sockets_denied() (line 60) — not in blueprint. flagged in YAGNI review, kept for robustness.

**adherance**: matches blueprint + one documented extra.

---

## vision adherance

### key vision statements

| vision statement | implemented? |
|------------------|--------------|
| "attacker's code hits a wall" | yes — ptrace scope=2 + flatpak overrides |
| "cannot read firefox memory" | yes — ptrace blocked |
| "cannot intercept dbus traffic" | partial — secrets blocked |
| "cannot access filesystem namespace" | yes — nofilesystem=home/host |
| "sandbox worked" | yes — verified by tests |

---

## deviations found

### deviation 1: test_x11_sockets_denied() extra

**location**: verify_wayland.sh line 60

**spec**: blueprint has 2 tests

**implementation**: has 3 tests

**assessment**: extra test, not a deviation from spec. documented in YAGNI review, kept for robustness.

**action**: none required — extra coverage is acceptable.

---

## summary

| component | adherance |
|-----------|-----------|
| configure_yama_ptrace() | exact match |
| configure_firefox_isolation() | exact match |
| verify_isolation.sh | exact match |
| verify_wayland.sh | matches + 1 extra |

no misinterpretations. no deviations from spec. implementation follows blueprint accurately.

