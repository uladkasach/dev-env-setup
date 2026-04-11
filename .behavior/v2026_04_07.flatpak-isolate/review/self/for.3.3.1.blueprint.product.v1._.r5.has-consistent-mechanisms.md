# self review: has-consistent-mechanisms (r5)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `src/install_env.pt1.system.performance.sh` — extant sysctl pattern
- `src/install_env.pt1.system.basics.sh` — extant flatpak install pattern
- `src/install_env.pt6.apps.sh` — extant flatpak install pattern

---

## codebase search results

### flatpak usage in repo

searched: `grep flatpak src/`

| file | usage | type |
|------|-------|------|
| `install_env.pt1.system.basics.sh:8` | `flatpak install flathub org.mozilla.firefox` | install |
| `install_env.pt4.terminal.sh:47-48` | `if ! flatpak list | grep -q ... then flatpak install` | idempotent install |
| `install_env.pt6.apps.sh:14-17` | `install_flatpak_apps()` with `flatpak install` | batch install |

**finding**: no `flatpak override` usage exists in the codebase. the blueprint introduces a new mechanism.

### sysctl usage in repo

searched: `grep sysctl src/`

| file | usage | method |
|------|-------|--------|
| `install_env.pt1.system.performance.sh:12-13` | `grep -q` guard + `tee -a /etc/sysctl.conf` | legacy append |
| `install_env.pt1.system.performance.sh:20-21` | `grep -q` guard + `tee -a /etc/sysctl.conf` | legacy append |
| `install_env.pt1.system.performance.sh:24` | `sudo sysctl -p` | legacy reload |

**finding**: extant code uses `/etc/sysctl.conf` (monolithic). blueprint uses `/etc/sysctl.d/` (modular).

### test scripts in repo

searched: `glob tests/**/*.sh`

**finding**: no test scripts exist. the `tests/` directory will be created fresh.

### idempotent guard patterns in repo

| file | guard pattern |
|------|---------------|
| `pt1.system.performance.sh:12` | `if ! grep -q '^fs.inotify...' /etc/sysctl.conf` |
| `pt1.system.performance.sh:41` | `if swapon --show | grep -q "$swapfile"` |
| `pt1.system.performance.sh:75` | `if command -v earlyoom &>/dev/null` |
| `pt4.terminal.sh:47` | `if ! flatpak list | grep -q app.devsuite.Ptyxis` |

**finding**: repo uses diverse idempotent guards. blueprint guards are consistent with these patterns.

---

## mechanism consistency analysis

### mechanism 1: flatpak override configuration

**what**: `flatpak override --user org.mozilla.firefox` with flags.

**duplication in repo?** no — searched `grep flatpak src/`, found only `flatpak install` and `flatpak run`. no override configuration exists.

**consistent with extant patterns?** yes — follows bash procedure pattern with idempotent guard (grep flatpak override --show).

**why it holds**: this is a new capability. the flatpak tool supports overrides natively. no extant utility to reuse.

**decision**: keep as designed.

---

### mechanism 2: sysctl configuration

**what**: write `/etc/sysctl.d/99-yama-ptrace.conf` and reload via `sysctl --system`.

**duplication in repo?** partial — `configure_sysctl()` at `install_env.pt1.system.performance.sh:7-24` exists.

**extant pattern (legacy)**:
```bash
if ! grep -q '^fs.inotify.max_user_watches=' /etc/sysctl.conf; then
  echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
fi
sudo sysctl -p
```

**blueprint pattern (modern)**:
```bash
write /etc/sysctl.d/99-yama-ptrace.conf
sudo sysctl --system
```

**inconsistency detected**: blueprint uses sysctl.d, extant uses sysctl.conf.

**which is correct?** sysctl.d is the modern standard:
- modular: each concern in separate file
- package-safe: survives system updates
- reversible: delete file to revert
- `sysctl --system` reloads all drop-ins

**why blueprint is correct**: the extant `configure_sysctl()` predates this behavior. it appends to a monolithic file, which is fragile. the blueprint uses the standard approach.

**decision**: keep sysctl.d in blueprint. flag `configure_sysctl()` for future refactor (out of scope — separate behavior).

---

### mechanism 3: verification scripts

**what**: `tests/verify_isolation.sh` and `tests/verify_wayland.sh`.

**duplication in repo?** no — `glob tests/**/*.sh` returns empty. no test infrastructure exists.

**consistent with extant patterns?** yes — follows repo convention of bash scripts with descriptive names and clear output.

**why it holds**: this creates new infrastructure. the `tests/` directory will contain verification procedures that output `[PASS]` or `[FAIL]` — a standard pattern for manual verification.

**decision**: keep as designed. this establishes the test infrastructure pattern for this repo.

---

### mechanism 4: idempotent guards

**what**: each procedure checks if work is already done before it runs.

**duplication in repo?** no — guards are procedure-specific.

**consistent with extant patterns?** yes. extant guards use:
- `if ! grep -q ... /etc/sysctl.conf` (file content check)
- `if swapon --show | grep -q` (command output check)
- `if command -v ... &>/dev/null` (command existence check)

blueprint guards use:
- `grep flatpak override --show` for marker (command output check)
- `check /proc/sys/kernel/yama/ptrace_scope` (file read check)

**why it holds**: the blueprint guards follow the same patterns as extant code. diverse guard types are acceptable — each fits its context.

**decision**: keep as designed.

---

## inconsistency findings

| mechanism | inconsistent? | action | evidence |
|-----------|---------------|--------|----------|
| flatpak override | no | keep | no extant override usage |
| sysctl.d vs sysctl.conf | yes (with extant code) | keep blueprint (modern) | `pt1.system.performance.sh:12-24` uses legacy |
| verification scripts | no | keep | no `tests/**/*.sh` exists |
| idempotent guards | no | keep | extant guards are diverse, blueprint fits |

---

## changes made to blueprint

none — the blueprint is correct. the sysctl.d approach should NOT be changed to match legacy code.

---

## reflection

one inconsistency found: the blueprint uses sysctl.d while `configure_sysctl()` uses sysctl.conf.

**why this is acceptable**:
1. sysctl.d is the correct modern approach per systemd standards
2. the blueprint should not perpetuate legacy patterns
3. a refactor of `configure_sysctl()` is out of scope (separate behavior)

**what i searched**:
- `grep flatpak src/` — found installs only, no overrides
- `grep sysctl src/` — found legacy sysctl.conf pattern
- `glob tests/**/*.sh` — found no test scripts
- read `install_env.pt1.system.performance.sh` for guard patterns

**rule applied**: when extant code uses a legacy pattern, new code should use the modern pattern. do not copy mistakes. flag legacy code for future refactor.

**traceability**: the sysctl.d decision aligns with research phase `3.1.2.research.external.factory.templates._.v1.stone` which identified systemd sysctl.d as the standard configuration method.

