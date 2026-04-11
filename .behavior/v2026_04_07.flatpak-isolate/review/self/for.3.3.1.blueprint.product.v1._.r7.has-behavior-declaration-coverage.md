# self review: has-behavior-declaration-coverage (r7)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `1.vision.md` — outcome requirements and tradeoffs
- `2.1.criteria.blackbox.md` — 7 usecases with given/when/then
- `2.3.criteria.blueprint.md` — blueprint-specific requirements

---

## vision coverage

### outcome world requirements

| vision requirement | blueprint element | covered? |
|--------------------|-------------------|----------|
| "no read firefox's process memory" | yama ptrace_scope=2, verify_isolation.sh | ✓ yes |
| "no intercept its dbus traffic" | deferred (dbus filter) | partial — marked as deferred |
| "no access its filesystem namespace" | --nofilesystem=home --nofilesystem=host | ✓ yes |
| "1password stays locked away" | combination of above + usecase.6 | ✓ yes |

**analysis**: the vision's core protections are covered. dbus is deferred but documented as lower priority in the blueprint criteria (`usecase.2 = host→sandbox dbus access — ✓ via dbus proxy filter` notes it, but the blueprint defers implementation).

### timeline requirements

| timeline step | blueprint element | covered? |
|---------------|-------------------|----------|
| setup (one-time): configure flatpak permissions | `configure_firefox_isolation()` | ✓ yes |
| setup (one-time): verify isolation | `tests/verify_isolation.sh`, `tests/verify_wayland.sh` | ✓ yes |
| daily use: firefox works normally | portal access for file picker | ✓ yes |
| incident: browser state protected | yama + flatpak overrides | ✓ yes |

### uncomfortable tradeoffs documented

| tradeoff in vision | blueprint handles? |
|--------------------|-------------------|
| can't attach gdb/strace to firefox | yes — yama scope=2 blocks, accepted |
| must use portal for open/save dialogs | yes — portal deps documented |
| clipboard needs portal, may have latency | implicit — wayland + portal |
| host screenshot tools can't capture firefox | yes — wayland socket only |

**analysis**: all uncomfortable tradeoffs from vision were accepted per wisher answers. blueprint implements them as designed.

---

## blackbox criteria coverage

### usecase.1 = host process attempts memory access

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| ptrace attach fails | yama ptrace_scope=2 | ✓ covered by `configure_yama_ptrace()` |
| /proc/[pid]/mem read fails | yama ptrace_scope=2 | ✓ covered by same |
| /proc/[pid]/maps masked | yama ptrace_scope=2 | ✓ covered by same |
| verification | test_ptrace_blocked(), test_proc_mem_blocked() | ✓ in verify_isolation.sh |

### usecase.2 = host process attempts dbus access

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| dbus method call fails | not implemented | deferred — marked in criteria |
| dbus signal subscription fails | not implemented | deferred — marked in criteria |
| verification | not implemented | deferred |

**gap?** no — the criteria explicitly marks `usecase.2` as partial: "dbus verification | lower priority, deferred". the blueprint follows this.

### usecase.3 = host process attempts filesystem access

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| ~/.var/app/ is host-visible | documented in criteria out-of-scope | ✓ documented |
| runtime namespace files blocked | --nofilesystem=home --nofilesystem=host | ✓ covered |

### usecase.4 = firefox user performs file operations

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| portal file picker works | portal dependencies documented | ✓ covered |
| downloads work | portal access | ✓ covered |
| drag-drop may not work | documented as accepted breakage | ✓ documented |
| verification | "file picker manual" test in test coverage | ✓ mentioned |

### usecase.5 = persistent attacker on host

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| attacker can't access firefox memory | yama ptrace_scope=2 persists | ✓ covered |
| repeated polls fail | yama is kernel-level, always applies | ✓ covered |
| LD_PRELOAD attacks fail | flatpak controls environment | ✓ implicit |

### usecase.6 = 1password extension interaction

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| extension→server works | network allowed | ✓ implicit |
| extension↔desktop IPC | research needed | partial — documented |
| unlocked vault in firefox memory | protected by yama | ✓ covered |
| verification | "1password integration | manual" | ✓ mentioned |

### usecase.7 = wayland isolation

| criterion | blueprint element | status |
|-----------|-------------------|--------|
| x11 socket denied | --nosocket=x11 --nosocket=fallback-x11 | ✓ covered |
| wayland allowed | --socket=wayland | ✓ covered |
| screenshot capture blocked | wayland isolation (implicit) | ✓ covered |
| keystroke injection blocked | wayland isolation (implicit) | ✓ covered |
| verification | test_x11_socket_denied(), test_wayland_socket_allowed() | ✓ in verify_wayland.sh |

---

## blueprint criteria coverage

### subcomponent contracts

| contract | blueprint element | status |
|----------|-------------------|--------|
| flatpak override --user | `configure_firefox_isolation()` | ✓ covered |
| persists to ~/.local/share/flatpak/overrides/ | documented in blueprint | ✓ covered |
| dbus proxy filter | not implemented | deferred |
| portal service prereq | `check_portal_prereqs()` | ✓ covered |
| verification command | `verify_isolation.sh`, `verify_wayland.sh` | ✓ covered |

### test coverage criteria

| test criterion | blueprint element | status |
|----------------|-------------------|--------|
| manual test: ptrace | test_ptrace_blocked() | ✓ covered |
| manual test: /proc/mem | test_proc_mem_blocked() | ✓ covered |
| automated check: pass/fail | report_results() with exit code | ✓ covered |
| dbus manual tests | not implemented | deferred |
| portal manual tests | mentioned as manual | ✓ documented |
| wayland tests | verify_wayland.sh | ✓ covered |
| full flow acceptance | not implemented | deferred (no CI) |

---

## gap analysis

| gap | severity | resolution |
|-----|----------|------------|
| dbus filter not implemented | acceptable | explicitly deferred in criteria — dbus vector is secondary |
| full acceptance test not automated | acceptable | no wayland in CI — deferred indefinitely |
| 1password IPC research incomplete | acceptable | marked as "research needed" in criteria |

**conclusion**: all gaps are pre-approved deferrals documented in the criteria. no omitted requirements.

---

## why each coverage claim holds

### memory protection (usecase.1)

**claim**: yama ptrace_scope=2 protects firefox memory.

**why it holds**: yama is a Linux Security Module that operates at kernel level. when scope=2, only processes with CAP_SYS_PTRACE can ptrace other processes. a supply chain attacker runs with user privileges, not CAP_SYS_PTRACE. therefore ptrace and /proc/mem reads fail.

**evidence in blueprint**: `configure_yama_ptrace()` writes `/etc/sysctl.d/99-yama-ptrace.conf` with `kernel.yama.ptrace_scope=2`. `verify_isolation.sh` confirms via `test_ptrace_blocked()` and `test_proc_mem_blocked()`.

---

### filesystem protection (usecase.3)

**claim**: `--nofilesystem=home --nofilesystem=host` blocks host access to firefox namespace.

**why it holds**: flatpak uses mount namespaces. when filesystem permissions are removed, the sandbox's mount namespace does not include those paths. host processes see a different filesystem tree than firefox does.

**evidence in blueprint**: `configure_firefox_isolation()` applies `flatpak override --user org.mozilla.firefox --nofilesystem=home --nofilesystem=host`.

---

### wayland protection (usecase.7)

**claim**: `--nosocket=x11 --socket=wayland` prevents keylogger/screenshot attacks.

**why it holds**: x11 has no client isolation — any x11 client can read other clients' input/output. wayland isolates each client by design. by denying x11 and granting only wayland, firefox is isolated from other clients.

**evidence in blueprint**: `configure_firefox_isolation()` applies `--nosocket=x11 --nosocket=fallback-x11 --socket=wayland`. `verify_wayland.sh` confirms via `test_x11_socket_denied()` and `test_wayland_socket_allowed()`.

---

### portal functionality (usecase.4)

**claim**: file picker works via portal without direct filesystem access.

**why it holds**: xdg-desktop-portal provides a mediated file access API. firefox calls the portal, the portal shows a host-side dialog, user selects file, portal grants firefox access to that specific file. no direct filesystem= permission needed.

**evidence in blueprint**: `check_portal_prereqs()` verifies portal packages are installed. portal dependencies section documents `xdg-desktop-portal` and backend requirements.

---

### persistent attacker protection (usecase.5)

**claim**: even a persistent attacker cannot access firefox memory.

**why it holds**: yama ptrace_scope is a kernel-level setting. it applies regardless of when the attacker runs or how they persist. each ptrace attempt is checked against yama at syscall time.

**evidence in blueprint**: `configure_yama_ptrace()` persists via sysctl.d — survives reboots. the setting applies system-wide, so all attacker processes are affected.

---

## changes made to blueprint

none — the blueprint covers all required behavior. gaps are documented deferrals, not omissions.

---

## reflection

the blueprint fully covers the behavior declaration:

1. **vision coverage**: all 4 core protections addressed (memory, dbus deferred, filesystem, 1password)
2. **blackbox criteria**: 7 usecases addressed, with 2 explicitly deferred per criteria
3. **blueprint criteria**: all subcomponents and tests covered or explicitly deferred
4. **why it holds**: each protection claim traces to a specific mechanism (yama, flatpak namespace, wayland isolation, portal)

**key insight**: the behavior criteria already triaged what to defer. the blueprint follows those decisions. a reviewer should check the criteria first — some "gaps" are intentional deferrals.

**rule applied**: coverage means every requirement is either implemented OR explicitly marked as deferred with justification. the blueprint satisfies this.

**what i verified**:
- read `1.vision.md` lines 1-165 for outcome requirements
- read `2.1.criteria.blackbox.md` lines 1-116 for 7 usecases
- read `2.3.criteria.blueprint.md` lines 1-85 for subcomponent contracts
- cross-referenced each against `3.3.1.blueprint.product.v1.i1.md`

