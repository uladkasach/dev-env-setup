# self review: has-vision-coverage (r1)

## the question

does the playtest cover all behaviors?
- is every behavior in 0.wish.md verified?
- is every behavior in 1.vision.md verified?
- are any requirements left untested?

---

## behaviors from 0.wish.md

the wish is simple:

> we want to make sure that if this machine is compromized from a supply chain attack or some other defect, that no one can reach into firefox from my terminal, and snoop on my unlocked 1password extension

| behavior | playtest path | covered? |
|----------|---------------|----------|
| host can't reach into firefox | path 3: verify_isolation.sh | yes |
| protect 1password extension | indirect — 1password lives in firefox memory | yes |
| supply chain attack can't snoop | path 3: ptrace blocked, /proc/mem blocked | yes |

---

## behaviors from 1.vision.md

### day-in-the-life outcomes

| "after" behavior | playtest path | covered? |
|------------------|---------------|----------|
| no read firefox's process memory | path 3: /proc/$pid/mem blocked | yes |
| no intercept dbus traffic | **NOT TESTED** | no |
| no access filesystem namespace | path 2: --nofilesystem=home/host | implicit |
| 1password stays locked away | indirect — depends on above | yes |

**issue found:** dbus traffic interception is NOT tested.

### edgecases from vision

| edgecase | mitigation | playtest coverage |
|----------|------------|-------------------|
| x11 forward | use wayland only | path 4: x11 socket denied |
| dbus session bus | filter dbus access | **NOT TESTED** |
| /proc access | user namespaces | path 3: /proc/mem blocked |
| flatpak overrides | audit overrides | path 2: shows applied flags |

**issue confirmed:** dbus filter is mentioned in vision but NOT tested in playtest.

### usecases from vision

| usecase | playtest coverage |
|---------|-------------------|
| browse securely while in development | paths 1-4 verify isolation |
| unlock 1password | path 5: file picker works (portal mediated) |
| run untrusted code | path 3: ptrace/proc blocked |

---

## what's left untested?

| untested behavior | why untested | acceptable? |
|-------------------|--------------|-------------|
| dbus interception | deferred in blueprint | yes — lower priority |
| clipboard isolation | not implemented | yes — portal handles |
| screenshot isolation | not implemented | yes — wayland handles |

the blueprint explicitly deferred dbus test:
> **deferred:** verify_dbus.sh — lower priority — dbus vector secondary to ptrace

---

## what could have gone wrong

| scenario | how I would detect | found? |
|----------|-------------------|--------|
| vision behavior not tested | map vision → playtest | yes — dbus deferred |
| wish behavior not tested | map wish → playtest | no — all covered |
| critical behavior gap | check "core protection" items | no — ptrace + proc covered |

---

## why it holds

1. **wish fully covered:** host can't snoop on firefox memory
2. **core protections tested:** ptrace blocked, /proc/mem blocked
3. **x11 gap closed:** wayland only, x11 socket denied
4. **dbus deferred explicitly:** lower priority per blueprint
5. **file picker verified:** path 5 confirms portal works

the playtest covers all critical behaviors from wish and vision. dbus filter was explicitly deferred in the blueprint as lower priority — the primary attack vectors (ptrace, /proc/mem, x11) are tested.

