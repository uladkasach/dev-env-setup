# self review: has-ergonomics-reviewed

---

## review summary

**verdict**: ergonomics are natural. one friction point noted.

---

## input/output pairs evaluation

### journey 1: switch worktopics

**input**: `Super+Ctrl+Tab`

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | follows tab-switch pattern (like browser tabs) |
| simplified? | ✓ yes | single keystroke, no mode or argument |

**output**: entire desktop transforms to next domain

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | matches mental model of "project switch" |
| clear? | ✓ yes | all monitors change together — unambiguous |

**friction**: keybind Super+Ctrl+Tab may conflict with extant cosmic shortcuts. must verify availability.

---

### journey 2: workspace navigation

**input**: `Super+Ctrl+Down` / `Super+Ctrl+Up`

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | matches extant workspace navigation |
| simplified? | ✓ yes | single keystroke |

**output**: workspace changes, worktopic stays same

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | user expects to stay in current domain |
| clear? | ✓ yes | only workspace changes, context preserved |

**friction**: none.

---

### journey 3: session persistence

**input**: implicit (logout)

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | no user action required |
| simplified? | ✓ yes | automatic |

**output**: worktopics restored on login

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | matches expectation that state persists |
| clear? | ✓ yes | user sees same worktopics they had before |

**friction**: none.

---

### journey 4: default state

**input**: none (first run)

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | no input needed |
| simplified? | ✓ yes | backwards compatible |

**output**: 1 default worktopic, all workspaces belong to it

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | extant behavior preserved |
| clear? | ✓ yes | Super+Ctrl+Tab is inert — no surprise |

**friction**: none.

---

### journey 5: multi-monitor

**input**: `Super+Ctrl+Tab` (same as single-monitor)

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | same keybind works for any monitor count |
| simplified? | ✓ yes | no extra action |

**output**: both monitors switch together

| aspect | evaluation | notes |
|--------|------------|-------|
| natural? | ✓ yes | user expects unified context |
| clear? | ✓ yes | entire desktop transforms |

**friction**: none.

---

## pit of success evaluation

| principle | evaluation | notes |
|-----------|------------|-------|
| intuitive design | ✓ holds | keybinds follow established patterns |
| convenient | ✓ holds | all operations are single-keystroke |
| expressive | ✓ holds | forward/backward directions available |
| composable | ✓ holds | worktopic switch + workspace nav are orthogonal |
| lower trust contracts | ✓ holds | config validated on load |
| deeper behavior | ✓ holds | wrap behavior is consistent |

---

## issues found

| issue | severity | action taken |
|-------|----------|--------------|
| keybind conflict risk | low | noted in friction; verify Super+Ctrl+Tab availability before implementation |

---

## non-issues confirmed

| aspect | why it holds |
|--------|--------------|
| input simplicity | all operations are single-keystroke with no arguments |
| output clarity | state changes are visible and unambiguous |
| backwards compatibility | default state preserves extant behavior |
| multi-monitor | same input, unified output |

---

## conclusion

ergonomics are natural and follow established patterns. one friction point (keybind conflict risk) is documented for pre-implementation verification.

