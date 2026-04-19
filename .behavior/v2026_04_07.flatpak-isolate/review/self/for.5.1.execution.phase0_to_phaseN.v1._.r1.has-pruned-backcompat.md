# self review: has-pruned-backcompat (r1)

## artifact reviewed

- `tests/verify_isolation.sh`
- `tests/verify_wayland.sh`
- `src/install_env.pt1.system.security.sh`

## question: backwards compat concerns?

### all files are new

all three files are new additions to the repo. there is no prior version to maintain compatibility with.

| file | status |
|------|--------|
| tests/verify_isolation.sh | new file |
| tests/verify_wayland.sh | new file |
| src/install_env.pt1.system.security.sh | new file |

### check for assumed compat

| potential concern | present? | analysis |
|-------------------|----------|----------|
| fallback for old flatpak versions | no | we use standard flatpak override flags |
| fallback for non-wayland systems | no | blueprint explicitly requires wayland, x11 blocked |
| fallback for absent strace | no | exits with clear error, no workaround added |
| fallback for absent portal | no | warns but does not block |

**verdict**: no backwards compatibility code was added.

---

## reflection

all files are new. no backwards compat shims, no "just in case" fallbacks. the code assumes the documented prereqs are met.

