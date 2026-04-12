# self review (r2): has-ergonomics-reviewed

---

## deeper review

fresh eyes after the first pass.

---

## what i missed in r1

upon reflection, i noticed i did not deeply question the keybind choices. let me do that now.

### keybind ergonomics deep dive

**Super+Ctrl+Tab for worktopic switch**

| question | answer |
|----------|--------|
| is this discoverable? | no — power user feature, requires documentation |
| does it conflict? | **unknown** — must verify against extant cosmic keybinds |
| is it memorable? | yes — follows ctrl+tab pattern for tab groups |
| is it comfortable? | **questionable** — three-key chord may be awkward |

**potential alternative**: Super+grave (`) — used by some window managers for workspace groups. simpler chord.

**decision**: keep Super+Ctrl+Tab as primary, but document alternative keybind in settings.

---

**Super+Ctrl+Up/Down for workspace navigation within worktopic**

| question | answer |
|----------|--------|
| does this conflict with extant? | must verify — Super+Ctrl+Up/Down may already be bound |
| is it consistent? | yes — matches extant workspace navigation pattern |
| is it comfortable? | yes — two-key chord + arrow is standard |

**decision**: holds.

---

## additional friction found

### friction: no visual feedback on worktopic switch

when user presses Super+Ctrl+Tab, there should be a brief visual indicator (toast or overlay) to show which worktopic they're now in. without this, users may be confused about whether the switch happened.

**fix**: add requirement for worktopic switch visual feedback to criteria.

---

### friction: keybind configuration

users who want different keybinds must edit config files (in MVP). this is acceptable friction for power users.

**decision**: acceptable for MVP. settings UI comes later.

---

## non-issues confirmed (deeper reasons)

### input simplicity

all operations are single-keystroke combos. no modes, no arguments, no dialogs. this is correct for frequent navigation actions.

### output clarity

state changes are visible (entire desktop changes). no ambiguous partial states. this is correct.

### backwards compatibility

default state (1 worktopic) preserves extant behavior exactly. Super+Ctrl+Tab is inert when only 1 worktopic exists. users who never configure worktopics experience zero change.

---

## issues found in r2

| issue | severity | action |
|-------|----------|--------|
| visual feedback on worktopic switch | medium | add to criteria |
| keybind conflict verification needed | low | add to pre-implementation checklist |
| three-key chord comfort | low | acceptable; document alternative |

---

## conclusion

ergonomics hold. one new issue found: need visual feedback on worktopic switch. this should be added to criteria (usecase.10 worktopic indicator may already cover this, but explicit toast/overlay should be considered).

