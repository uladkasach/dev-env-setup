# self review: has-divergence-analysis (r1)

## hostile reviewer perspective

what would a skeptical reviewer find that I overlooked?

---

## summary comparison

### blueprint declares

| deliverable | purpose |
|-------------|---------|
| `configure_firefox_isolation()` | apply restrictive flatpak overrides |
| `configure_yama_ptrace()` | set kernel ptrace_scope=2 |
| portal configuration | enable file picker without filesystem= override |

### implementation provides

| deliverable | purpose |
|-------------|---------|
| `configure_firefox_isolation()` | apply restrictive flatpak overrides |
| `configure_yama_ptrace()` | set kernel ptrace_scope=2 |
| `check_portal_prereqs()` | warn if xdg-desktop-portal absent |

**divergence found?** possibly — blueprint says "portal configuration", implementation has "check_portal_prereqs".

**analysis:** blueprint says "portal configuration" → "enable file picker without filesystem= override". the implementation checks if portal is installed and warns if absent. it does not *configure* the portal — the portal works by default when installed.

**verdict:** no divergence. the blueprint's intent (file picker works) is achieved. "portal configuration" was interpreted as "portal prereq validation" because portals are self-configured.

---

## filediff comparison

### blueprint declares

```
src/
└─ [+] install_env.pt1.system.security.sh
   ├─ [+] configure_firefox_isolation()
   └─ [+] configure_yama_ptrace()

tests/
├─ [+] verify_isolation.sh          # (from factory blueprint)
└─ [+] verify_wayland.sh            # (from factory blueprint)
```

### implementation provides

```
src/
└─ [+] install_env.pt1.system.security.sh
   ├─ configure_yama_ptrace()
   ├─ check_portal_prereqs()     # EXTRA: not in blueprint filediff
   └─ configure_firefox_isolation()

tests/
├─ [+] verify_isolation.sh
└─ [+] verify_wayland.sh
```

**divergence found?** yes — `check_portal_prereqs()` is extra.

**analysis:** blueprint product codepath tree does *not* list `check_portal_prereqs()` as a standalone function. it is listed under `configure_firefox_isolation()` as:

```
├─ [+] check_portal_prereqs()
│  └─ verify xdg-desktop-portal installed, warn if not
```

**verdict:** no divergence. `check_portal_prereqs()` is documented in the codepath tree under configure_firefox_isolation. the filediff tree in the evaluation shows it as a top-level function (which is how it was implemented), but the blueprint's codepath tree shows it as a subfunction. both are accurate — the filediff shows file structure, the codepath shows call hierarchy.

---

## codepath comparison

### blueprint declares (configure_firefox_isolation)

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

### implementation provides

```
configure_firefox_isolation()
├─ check firefox flatpak installed (early return)     # EXTRA
├─ call check_portal_prereqs()
├─ idempotent guard (grep override file for markers)
├─ apply overrides (6 flags)
└─ echo progress with flag summary
```

**divergence found?** yes — "check firefox flatpak installed" is extra.

**analysis:** the blueprint does not specify what happens if firefox flatpak is not installed. the implementation adds an early return:

```bash
if ! flatpak info org.mozilla.firefox &>/dev/null; then
  echo "• firefox flatpak not installed (skip)"
  return 0
fi
```

**verdict:** acceptable divergence. this is defensive code that prevents errors when firefox is absent. it follows rule.require.failfast — the function handles a prereq failure gracefully instead of an error.

---

## test coverage comparison

### blueprint declares

| test | covers usecase | method |
|------|----------------|--------|
| `tests/verify_isolation.sh` | 1, 5, 6 | ptrace, /proc/mem, yama scope |
| `tests/verify_wayland.sh` | 7 | x11 denied, wayland allowed |
| file picker manual | 4 | user clicks upload, selects file |

### implementation provides

same as blueprint, plus:
- `test_x11_sockets_denied()` in verify_wayland.sh

**divergence found?** yes — extra test.

**verdict:** already documented in evaluation. acceptable divergence — adds robustness.

---

## all divergences found

| divergence | documented in evaluation? | resolution |
|------------|---------------------------|------------|
| extra test_x11_sockets_denied() | yes | backup (acceptable) |
| extra "check firefox flatpak installed" | **no** | needs to be added |
| check_portal_prereqs as standalone function | no divergence | blueprint codepath shows it |

---

## issue found

the evaluation's divergence analysis does not mention the "check firefox flatpak installed" guard.

**fix:** update evaluation to document this divergence.

---

## after fix

updated 5.2.evaluation.v1.i1.md to include:

| divergence | resolution | rationale |
|------------|------------|-----------|
| extra test_x11_sockets_denied() | backup | adds robustness |
| extra firefox flatpak installed check | backup | defensive code, prevents error when firefox absent |

