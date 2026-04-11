# self-review r3: has-questioned-questions

## verification of triaged questions

### assumptions — verified

| assumption | tag | rationale |
|------------|-----|-----------|
| cosmic uses wayland | [answered] | **holds**: cosmic-comp is definitionally a wayland compositor |
| flatpak prevents host-to-guest | [research] | **holds**: this is the core hypothesis — requires technical verification |
| 1password data in sandbox | [research] | **holds**: 1password's architecture is documented but not locally known |
| dbus filter is practical | [research] | **holds**: depends on flatpak's dbus proxy capabilities |

### wisher questions — verified

| question | tag | rationale |
|----------|-----|-----------|
| ok with feature breakage? | [wisher] | **holds**: only wisher can accept/reject tradeoffs |
| need file share? | [wisher] | **holds**: workflow-specific |
| only firefox or others? | [wisher] | **holds**: scope decision |
| desktop app or browser-only? | [wisher] | **holds**: only wisher knows their setup |
| transient or persistent threats? | [wisher] | **holds**: threat model decision |

### research questions — verified

| question | tag | rationale |
|----------|-----|-----------|
| ptrace blocked? | [research] | **holds**: requires kernel/namespace docs or experiment |
| /proc/mem readable? | [research] | **holds**: requires namespace documentation |
| firefox dbus interfaces? | [research] | **holds**: requires dbus introspection |
| 1password secrets location? | [research] | **holds**: requires 1password docs |
| namespace symmetry? | [research] | **holds**: the fundamental question — research critical |

---

## issues found — none

all questions are:
- appropriately triaged
- tagged in the vision document
- separated into clear categories

the vision now clearly distinguishes:
- what we know (answered)
- what we need to research (research)
- what we need to ask the wisher (wisher)

---

## what i learned

1. **triage before research**: don't research all topics. some questions can be answered now via logic. some only the wisher knows.

2. **separate categories matter**: research questions go to research phase. wisher questions should be asked before research (to scope the research).

3. **the "namespace symmetry" question is the linchpin**: if namespaces are asymmetric by design, the entire approach may need rethink. this is the highest-priority research question.
