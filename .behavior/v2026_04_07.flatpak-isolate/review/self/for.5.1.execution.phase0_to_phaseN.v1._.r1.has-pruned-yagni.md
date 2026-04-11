# self review: has-pruned-yagni (r1)

## artifact reviewed

- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`
- `src/install_env.pt1.system.security.sh`

## question: was all code prescribed?

### verify_isolation.sh

| component | prescribed? | evidence |
|-----------|-------------|----------|
| check_prereqs() | yes | blueprint line 77-78 |
| find_firefox_pid() | yes | blueprint line 79-81 |
| test_yama_scope() | yes | blueprint line 83-86 |
| test_ptrace_blocked() | yes | blueprint line 88-90 |
| test_proc_mem_blocked() | yes | blueprint line 92-96 |
| report_results() | yes | blueprint line 98-100 |

**verdict**: no YAGNI detected.

---

### verify_wayland.sh

| component | prescribed? | evidence |
|-----------|-------------|----------|
| test_x11_socket_denied() | yes | blueprint line 108-111 |
| test_wayland_socket_allowed() | yes | blueprint line 113-116 |
| test_x11_sockets_denied() | **NO** | not in blueprint |
| report_results() | yes | blueprint line 118-119 |

**issue found**: `test_x11_sockets_denied()` was added but not prescribed.

**analysis**: this test checks if the flatpak override file contains `nosocket=x11`. it verifies configuration was applied, not just runtime behavior.

**decision**: KEEP. rationale:
- it's 15 lines, minimal complexity
- it catches config drift (override removed but test passes because x11 absent)
- the test name makes intent clear
- user can delete if unwanted

if strict YAGNI, remove it. flagged for wisher decision.

---

### install_env.pt1.system.security.sh

| component | prescribed? | evidence |
|-----------|-------------|----------|
| configure_yama_ptrace() | yes | blueprint line 60-67 |
| check_portal_prereqs() | yes | blueprint line 49-50 |
| configure_firefox_isolation() | yes | blueprint line 48-58 |
| --no-talk-name=org.freedesktop.secrets | yes | added to blueprint per user request |

**verdict**: no YAGNI detected.

---

## summary

| file | extras found | action |
|------|--------------|--------|
| verify_isolation.sh | none | none |
| verify_wayland.sh | test_x11_sockets_denied() | flagged, kept |
| install_env.pt1.system.security.sh | none | none |

## reflection

one extra test function was added. it provides defense-in-depth verification but was not prescribed. flagged for wisher awareness. no other YAGNI detected.

