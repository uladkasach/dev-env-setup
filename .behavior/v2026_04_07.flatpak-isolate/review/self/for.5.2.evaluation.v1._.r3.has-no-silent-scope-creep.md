# self review: has-no-silent-scope-creep (r3)

## scope boundary check

the blueprint specified:
- `configure_firefox_isolation()` — apply restrictive flatpak overrides
- `configure_yama_ptrace()` — set kernel ptrace_scope=2
- portal prereq check — warn if xdg-desktop-portal absent
- `tests/verify_isolation.sh` — test ptrace and /proc/mem blocked
- `tests/verify_wayland.sh` — test x11 denied, wayland allowed

## scope creep audit

### did I add features not in the blueprint?

| addition | in blueprint? | verdict |
|----------|---------------|---------|
| test_x11_sockets_denied() | no | **documented divergence** — backup in evaluation |
| firefox flatpak installed check | no | **documented divergence** — backup in evaluation |
| verify after mutation in yama | no | **documented in codepath tree** — defensive, not scope creep |
| check_prereqs() in verify_isolation | yes | blueprint: "verify strace installed, exit with instructions" |
| semantic exit codes (0, 1, 2) | yes | blueprint implied via "exit code: 0=all pass, 1=any fail" |

**result:** no silent scope creep. all additions are documented.

### did I change things "while I was in there"?

| file | changes beyond blueprint | verdict |
|------|--------------------------|---------|
| install_env.pt1.system.security.sh | none — file created new | n/a |
| verify_isolation.sh | none — file created new | n/a |
| verify_wayland.sh | extra test | documented divergence |

no extant files were touched. no "while I was in there" refactors occurred.

### did I refactor code unrelated to the wish?

no. the implementation touched only:
- `src/install_env.pt1.system.security.sh` (new)
- `tests/verify_isolation.sh` (new)
- `tests/verify_wayland.sh` (new)

no other files in the repo were modified.

---

## why scope stayed contained

1. **blueprint was precise** — filediff tree and codepath tree gave clear targets
2. **new files only** — no temptation to refactor extant code
3. **divergences documented immediately** — extra test called out in evaluation

---

## what could have gone wrong

1. **could have added dbus verification** — blueprint deferred it, I respected that
2. **could have added CI automation** — blueprint said "no wayland in CI", I respected that
3. **could have refactored other install_env.*.sh files** — stayed focused on new file

---

## summary

no silent scope creep detected:
- all additions documented as divergences
- no extant code touched
- no features beyond blueprint (except documented divergences)

scope contained. review complete.

