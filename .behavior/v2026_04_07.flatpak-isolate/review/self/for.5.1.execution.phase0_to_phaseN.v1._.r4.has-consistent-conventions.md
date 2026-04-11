# self review: has-consistent-conventions (r4)

## artifact reviewed

- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`
- `src/install_env.pt1.system.security.sh`

compared against:
- `src/install_env.pt1.system.basics.sh`
- `src/install_env.pt1.system.performance.sh`

---

## divergence analysis

### 1. header comment length

| file | header |
|------|--------|
| extant (basics.sh) | `######################################################################` (70 chars) |
| extant (performance.sh) | `######################################################################` (70 chars) |
| mine (security.sh) | `#########################` (25 chars) |

**divergence found**: my header is shorter.

**decision**: minor aesthetic. not worth a refactor. both are valid bash comment blocks. the 70-char rule is convention, not requirement. documented, not fixed.

---

### 2. set -euo pipefail

| file | has strict mode? |
|------|------------------|
| extant (basics.sh) | no |
| extant (performance.sh) | no |
| mine (security.sh) | yes |

**divergence found**: my file has `set -euo pipefail`, extant files do not.

**analysis**: this is a *better* practice (fail-fast on errors, undefined vars, pipe failures). the divergence is intentional improvement.

**decision**: keep. divergence is positive. documented, not reverted.

---

### 3. function comment style

| file | function comments |
|------|-------------------|
| extant (basics.sh) | none |
| extant (performance.sh) | inline `#####` blocks |
| mine (security.sh) | `## function_name` header blocks |

**analysis**: my style is more formal with explicit `.what`, `.why`, idempotent notes. extant styles vary (some have none, some have inline).

**decision**: keep. my style is clearer. documented, not reverted.

---

## function name conventions

### extant patterns

```
install_*     → install a tool
configure_*   → configure a tool
uninstall_*   → remove a tool
format_*      → format output
extract_*     → parse/extract data
print_*       → output data
```

### my functions

| function | matches pattern? |
|----------|------------------|
| `configure_yama_ptrace` | yes — follows `configure_*` |
| `check_portal_prereqs` | new pattern — but `check_*` is standard bash idiom |
| `configure_firefox_isolation` | yes — follows `configure_*` |

**verdict**: no conflict. `check_*` is new but sensible.

---

## file name conventions

extant pattern: `install_env.ptN.category.subcategory.sh`

| extant | mine |
|--------|------|
| `install_env.pt1.system.basics.sh` | `install_env.pt1.system.security.sh` |
| `install_env.pt1.system.keybinds.sh` | |
| `install_env.pt1.system.performance.sh` | |

my file: `install_env.pt1.system.security.sh` — follows `install_env.pt1.system.{category}.sh` pattern exactly.

**verdict**: consistent.

---

## test file conventions

no extant test files. my files set precedent:

| file | pattern |
|------|---------|
| `tests/verify_isolation.sh` | `verify_*` — describes verification purpose |
| `tests/verify_wayland.sh` | `verify_*` — describes verification purpose |

**verdict**: new precedent, no conflict. `verify_*` is standard for verification scripts.

---

## summary

| aspect | verdict | action |
|--------|---------|--------|
| header length | divergence (shorter) | documented, acceptable |
| set -euo pipefail | divergence (added) | documented, intentional improvement |
| function comment style | divergence (more formal) | documented, clearer |
| function prefixes | consistent | no action |
| file names | consistent | no action |
| test file names | new precedent | no action |

three divergences found. all are improvements or acceptable variations. no regressions.

