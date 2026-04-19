# self review: has-consistent-conventions (r3)

## artifact reviewed

- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`
- `src/install_env.pt1.system.security.sh`

## name convention search

searched extant `src/install_env.pt1.system.*.sh` for function name patterns:

| prefix | purpose | examples |
|--------|---------|----------|
| `install_*` | install a tool | install_keyd, install_firefox, install_earlyoom |
| `configure_*` | configure a tool | configure_keyd, configure_sysctl, configure_swapfile |
| `check_*` | validation | (none found in extant, but pattern is clear) |
| `format_*`, `extract_*`, `print_*` | utilities | format_top_procs, extract_pids, print_proc_details |

---

## my functions vs convention

| my function | matches? | notes |
|-------------|----------|-------|
| `configure_yama_ptrace` | yes | follows `configure_*` pattern |
| `check_portal_prereqs` | yes | `check_*` is standard bash pattern, not extant but not conflict |
| `configure_firefox_isolation` | yes | follows `configure_*` pattern |

---

## file name convention

extant pattern: `install_env.ptN.category.sh` or `install_env.ptN.category.subcategory.sh`

| extant | mine |
|--------|------|
| `install_env.pt1.system.basics.sh` | `install_env.pt1.system.security.sh` |
| `install_env.pt1.system.keybinds.sh` | |
| `install_env.pt1.system.performance.sh` | |

my file: `install_env.pt1.system.security.sh` — follows `install_env.pt1.system.{category}.sh` pattern.

verdict: consistent.

---

## test file convention

no extant tests. my files set precedent:

| file | rationale |
|------|-----------|
| `tests/verify_isolation.sh` | `verify_*` describes what test does |
| `tests/verify_wayland.sh` | `verify_*` describes what test does |

`verify_*` is standard for verification scripts. no conflict.

---

## variable name conventions

searched extant for local variable patterns:

| extant | mine |
|--------|------|
| `local current_scope` | `local current_scope` |
| `local sysctl_file` | `local sysctl_file` |
| `local output` | `local output` |
| `local pid` | `local pid` |

all snake_case, all use `local`. consistent.

---

## summary

| aspect | verdict |
|--------|---------|
| function prefixes | consistent |
| file names | consistent |
| test file names | new precedent, no conflict |
| variable names | consistent |

no divergence from extant conventions.

