# self review: has-consistent-conventions (r6)

## artifact reviewed

`.behavior/v2026_04_07.flatpak-isolate/3.3.1.blueprint.product.v1.i1.md`

## reference documents

- `src/install_env.*.sh` — extant file name patterns
- procedure names via `grep '^[a-z_]+\(\)' src/`

---

## codebase search results

### file name conventions

searched: `glob src/install_env*.sh`

| pattern | examples |
|---------|----------|
| `install_env.pt{N}.{category}.sh` | `pt1.system.basics.sh`, `pt2.shell.sh`, `pt4.terminal.sh` |
| `install_env.pt{N}.{category}.{subcategory}.sh` | `pt1.system.keybinds.sh`, `pt1.system.performance.sh`, `pt2.shell.git.aliases.sh` |

**extant pt1.system.* files**:
- `install_env.pt1.system.basics.sh`
- `install_env.pt1.system.keybinds.sh`
- `install_env.pt1.system.performance.sh`

**blueprint proposes**: `install_env.pt1.system.security.sh`

**result**: follows `pt{N}.{category}.{subcategory}` pattern. consistent.

### procedure name conventions

searched: `grep '^[a-z_]+\(\)' src/`

| prefix | what it does | examples |
|--------|--------------|----------|
| `install_*` | install software | `install_firefox`, `install_keyd`, `install_docker` |
| `configure_*` | configure software | `configure_keyd`, `configure_sysctl`, `configure_git` |
| `uninstall_*` | remove software | `uninstall_runaway_monitor` |
| `_function_name` | private/internal | `_git_tree_get`, `_machine_usage_diagnose` |

**blueprint proposes**:
- `configure_firefox_isolation()` — uses `configure_*` prefix
- `configure_yama_ptrace()` — uses `configure_*` prefix

**result**: both procedures follow `configure_*` convention. consistent.

### test file conventions

searched: `glob tests/**/*.sh`

**result**: no test files exist. blueprint establishes new convention.

**blueprint proposes**:
- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`

**analysis**: `verify_*` is a reasonable prefix for verification scripts. no conflict with extant patterns.

---

## convention consistency analysis

### convention 1: file name `install_env.pt1.system.security.sh`

**extant pattern**: `install_env.pt{N}.{category}.{subcategory}.sh`

**blueprint fit**: `install_env.pt1.system.security.sh` follows pattern exactly.

**why it holds**: pt1 = system level, system = category, security = subcategory. matches extant files like `pt1.system.keybinds.sh` and `pt1.system.performance.sh`.

**decision**: keep as designed.

---

### convention 2: procedure name `configure_firefox_isolation()`

**extant pattern**: `configure_*` for configuration procedures.

**examples from repo**:
- `configure_keyd()` — configure key remapper
- `configure_sysctl()` — configure kernel params
- `configure_ptyxis()` — configure terminal

**blueprint fit**: `configure_firefox_isolation()` follows pattern.

**why it holds**: the procedure configures flatpak overrides. it does not install software (no `install_*` prefix). configuration is the action.

**decision**: keep as designed.

---

### convention 3: procedure name `configure_yama_ptrace()`

**extant pattern**: `configure_*` for configuration procedures.

**blueprint fit**: `configure_yama_ptrace()` follows pattern.

**why it holds**: the procedure configures a kernel parameter via sysctl. same as `configure_sysctl()` which exists in repo.

**decision**: keep as designed.

---

### convention 4: test file names `verify_*.sh`

**extant pattern**: none — no test files exist in `tests/`.

**blueprint proposes**: `verify_isolation.sh`, `verify_wayland.sh`

**analysis**: `verify_*` is descriptive. the scripts verify that isolation works. this establishes a new convention for the `tests/` directory.

**alternative considered**: `test_*.sh` — but "test" is overloaded (could refer to unit test). "verify" is more precise for manual verification procedures.

**why it holds**: `verify_*` clearly communicates purpose — these are verification procedures, not automated tests.

**decision**: keep as designed.

---

### convention 5: idempotent guard output

**extant pattern**: procedures echo progress with `•` bullet:
- `echo "• swapfile already active; skipped"`
- `echo "• earlyoom already installed; skipped"`
- `echo "• runaway_monitor installed and enabled"`

**blueprint proposes**:
- `echo "• firefox flatpak overrides applied"`
- `echo "• yama ptrace_scope set to 2"`

**result**: follows extant bullet point convention. consistent.

**decision**: keep as designed.

---

## divergence results

| element | divergent? | action |
|---------|------------|--------|
| file name `install_env.pt1.system.security.sh` | no | keep |
| procedure `configure_firefox_isolation()` | no | keep |
| procedure `configure_yama_ptrace()` | no | keep |
| test files `verify_*.sh` | new convention | keep — establishes pattern |
| output format `• message` | no | keep |

---

## changes made to blueprint

none — all names and patterns are consistent with extant conventions.

---

## traceability matrix

| blueprint element | extant convention | source | verdict |
|-------------------|-------------------|--------|---------|
| `install_env.pt1.system.security.sh` | `install_env.pt{N}.{category}.{subcategory}.sh` | `glob src/install_env*.sh` | ✓ consistent |
| `configure_firefox_isolation()` | `configure_*` for config procedures | `grep '^configure_' src/` | ✓ consistent |
| `configure_yama_ptrace()` | `configure_*` for config procedures | `grep '^configure_' src/` | ✓ consistent |
| `tests/verify_isolation.sh` | none (new directory) | `glob tests/**/*.sh` | ✓ establishes pattern |
| `tests/verify_wayland.sh` | none (new directory) | `glob tests/**/*.sh` | ✓ establishes pattern |
| output `• message` | `• {action}` bullets | `install_env.pt1.system.performance.sh:43,77,82` | ✓ consistent |

---

## reflection

no divergences found. the blueprint adheres to extant conventions.

**detailed analysis per convention**:

1. **file name**: `install_env.pt1.system.security.sh` follows the extant pattern where pt1 = system-level configs, and subcategories like `keybinds`, `performance`, `basics` exist. `security` fits this taxonomy — it is a system-level concern like keybinds and performance.

2. **procedure prefix**: `configure_*` is the correct prefix because the procedures modify configuration state but do not install software. the distinction matters: `install_keyd()` installs keyd, then `configure_keyd()` configures it. similarly, firefox flatpak is already installed — we configure its isolation.

3. **test file prefix**: `verify_*` was chosen over `test_*` to avoid ambiguity. in this repo, "test" could imply automated unit tests (which would run in CI). "verify" signals manual verification procedures that require a wayland session — they cannot run in CI.

4. **output bullets**: all extant procedures use `• {action completed}` format for progress output. the blueprint follows this exact pattern.

**what i searched**:
- `glob src/install_env*.sh` — 12 files, analyzed name patterns
- `grep '^[a-z_]+\(\)' src/` — 100+ procedures, analyzed prefix patterns
- `grep "echo.*•" src/install_env.pt1.system.performance.sh` — verified bullet format
- `glob tests/**/*.sh` — confirmed no extant test files

**rule applied**: unless the ask was to refactor, be consistent with extant conventions. the blueprint is consistent.

**why this matters**: convention consistency enables discoverability. a developer who knows `configure_*` is for configuration can predict procedure names. a developer who knows `pt1.system.*` is for system-level configs can predict file locations.

