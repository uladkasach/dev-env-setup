# self review: has-divergence-addressed (r2)

## skeptical examination

for each divergence, ask:
- is this truly an improvement, or laziness?
- did we avoid work the blueprint required?
- could this divergence cause problems later?

---

## divergence 1: extra test_x11_sockets_denied()

### what was declared
blueprint declares 2 tests:
- test_x11_socket_denied()
- test_wayland_socket_allowed()

### what was implemented
3 tests:
- test_x11_socket_denied()
- test_wayland_socket_allowed()
- test_x11_sockets_denied() **extra**

### backup rationale
the extra test verifies that `nosocket=x11` and `nosocket=fallback-x11` flags are set in flatpak overrides, not just that the x11 socket is invisible inside the sandbox.

### skeptical questions

**is this truly an improvement?**

yes. the blueprint's test checks socket *visibility* — whether firefox can *see* the x11 socket. the extra test checks *configuration* — whether the override flags are *applied*. these are independent concerns:
- socket could be invisible because x11 is not active, not because of overrides
- overrides could be applied but x11 still visible (misconfiguration)

the extra test catches the second case.

**did we avoid work the blueprint required?**

no. all blueprint tests are present. this adds to them.

**could this divergence cause problems later?**

no. the test is additive and does not affect other tests. if flatpak changes its override format, the test would fail but that would surface a real issue.

### verdict
**backup valid** — this is a genuine improvement, not laziness.

---

## divergence 2: extra firefox flatpak installed check

### what was declared
blueprint does not specify behavior when firefox flatpak is absent.

### what was implemented
early return with message:
```bash
if ! flatpak info org.mozilla.firefox &>/dev/null; then
  echo "• firefox flatpak not installed (skip)"
  return 0
fi
```

### backup rationale
prevents flatpak override command from an error when firefox is absent.

### skeptical questions

**is this truly an improvement?**

yes. without this check, `flatpak override --user org.mozilla.firefox ...` would error:
```
error: No installed runtime or application has the ID org.mozilla.firefox
```

the user would see an error but not understand why. the early return with message is clearer.

**did we avoid work the blueprint required?**

no. the blueprint does not require behavior when firefox is absent. it assumes firefox is installed (which is reasonable for the usecase). the implementation gracefully handles the case the blueprint did not address.

**could this divergence cause problems later?**

no. the check is at the start of the function. if firefox becomes installed later, the function will proceed normally. the check is idempotent and has no side effects.

### verdict
**backup valid** — this is defensive code that improves user experience.

---

## meta-question: are there divergences we should have repaired instead of backed up?

| divergence | repair possible? | repair better? |
|------------|------------------|----------------|
| extra test | could delete | no — test adds value |
| firefox check | could delete | no — error prevention adds value |

no divergences should be repaired. all backups are justified.

---

## summary

both divergences have valid backup rationale:
1. extra test — catches configuration issues independent of visibility
2. firefox check — prevents confuse error message

neither is laziness. neither avoided required work. neither causes future problems.

divergence resolution is complete and valid.

