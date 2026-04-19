# self review: has-pruned-backcompat (r2)

## artifact reviewed

- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`
- `src/install_env.pt1.system.security.sh`

## deeper review

### why no backwards compat was added

**context**: all three files are new. but that doesn't mean I couldn't have added backwards compat code "just in case".

let me examine each potential compat concern and articulate why it was NOT added.

---

### verify_isolation.sh

#### potential: fallback if pgrep fails

```bash
# I wrote:
pid=$(pgrep -f "firefox.*flatpak" 2>/dev/null | head -1) || true
if [[ -z "$pid" ]]; then
  pid=$(flatpak ps ...)
fi
```

**question**: is the `flatpak ps` fallback backwards compat?

**answer**: no. this is not compat for old systems. `pgrep` may simply not find the process if the command line doesn't match the pattern. `flatpak ps` is a different lookup method, not a compat shim. both are documented methods to find flatpak processes.

#### potential: support for non-flatpak firefox

**question**: should verify_isolation.sh work with non-flatpak firefox?

**answer**: no. the vision explicitly states "firefox flatpak". the blueprint explicitly tests flatpak isolation. non-flatpak firefox is out of scope. no compat was added, correctly.

---

### verify_wayland.sh

#### potential: support for x11 systems

**question**: should verify_wayland.sh gracefully handle x11-only systems?

**answer**: no. the blueprint says "use wayland only". the vision says cosmic wayland compositor. x11 support was explicitly rejected in the vision under "edgecases":

> | x11 forward | any x11 app can keylog others | use wayland only |

no x11 compat was added, correctly.

---

### install_env.pt1.system.security.sh

#### potential: support for old flatpak without --no-talk-name

**question**: should we check flatpak version before use of --no-talk-name?

**answer**: no. `--no-talk-name` was added in flatpak 1.0 (2018). any system old enough to lack it is out of scope. no version check was added, correctly.

#### potential: support for systems without sysctl.d

**question**: should we fall back to /etc/sysctl.conf if sysctl.d absent?

**answer**: no. sysctl.d has been standard since systemd adoption (~2012). any system without it is ancient. no fallback was added, correctly.

#### potential: preserve extant ptrace_scope value

**question**: should we save the old ptrace_scope value before overwrite?

**answer**: no. the user explicitly requested scope=2. there is no "restore to previous" use case documented. no backup/restore was added, correctly.

---

## summary

| potential compat | added? | why not |
|------------------|--------|---------|
| pgrep fallback | no (not compat, just alternate lookup) | n/a |
| non-flatpak firefox | no | out of scope per vision |
| x11 systems | no | explicitly rejected in vision |
| old flatpak versions | no | --no-talk-name is 6+ years old |
| systems without sysctl.d | no | standard since 2012 |
| preserve old ptrace_scope | no | no restore use case |

---

## why this holds

the code assumes:
1. flatpak 1.0+ (reasonable, 2018+)
2. systemd with sysctl.d (reasonable, 2012+)
3. wayland compositor (explicitly required)
4. firefox flatpak (explicitly required)

these are stated prereqs, not assumed compat. no "just in case" code was added.

