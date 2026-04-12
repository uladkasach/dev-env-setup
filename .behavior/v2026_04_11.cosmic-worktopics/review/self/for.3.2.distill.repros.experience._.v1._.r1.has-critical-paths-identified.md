# self review: has-critical-paths-identified

---

## review summary

**verdict**: critical paths are identified and hold.

---

## critical path 1: worktopic switch

**description**: Super+Ctrl+Tab changes entire context

**why critical**: core value proposition — this is the unlock

### pit of success evaluation

| aspect | evaluation | notes |
|--------|------------|-------|
| narrower inputs | ✓ holds | single keybind, no arguments |
| convenient | ✓ holds | muscle memory, no mode switch needed |
| expressive | ✓ holds | Super+Shift+Tab for reverse direction |
| failsafes | ✓ holds | wraps to first worktopic on overflow |
| failfasts | n/a | navigation cannot fail (always valid state) |
| idempotency | ✓ holds | can press repeatedly, state is deterministic |

### what if it failed?

if worktopic switch fails, the entire product fails. users cannot separate domains. this is the sole purpose of worktopics.

---

## critical path 2: workspace navigation

**description**: Super+Ctrl+Down stays within worktopic

**why critical**: prevents domain pollution

### pit of success evaluation

| aspect | evaluation | notes |
|--------|------------|-------|
| narrower inputs | ✓ holds | single keybind, no arguments |
| convenient | ✓ holds | matches extant workspace navigation (Super+Ctrl+Up/Down) |
| expressive | ✓ holds | up/down directions available |
| failsafes | ✓ holds | wraps within worktopic boundaries |
| failfasts | n/a | navigation cannot fail |
| idempotency | ✓ holds | deterministic state |

### what if it failed?

if workspace navigation crosses worktopics, users accidentally land in wrong domain. defeats the purpose.

---

## critical path 3: session restore

**description**: worktopics persist across logout/login

**why critical**: users lose trust if state is lost

### pit of success evaluation

| aspect | evaluation | notes |
|--------|------------|-------|
| narrower inputs | ✓ holds | implicit (no user input) |
| convenient | ✓ holds | automatic on logout, automatic on login |
| expressive | n/a | no user expression needed |
| failsafes | ✓ holds | default config (1 worktopic) if no saved state |
| failfasts | **needs attention** | should fail clearly if config is corrupt |
| idempotency | ✓ holds | save/load is idempotent |

### what if it failed?

if session restore fails silently, users lose carefully arranged worktopics. if it fails loudly, users know to report a bug.

**action needed**: ensure config load fails clearly on corruption, not silently. document this in criteria.

---

## critical path 4: default state

**description**: single worktopic, backwards compatible

**why critical**: extant users must not be broken

### pit of success evaluation

| aspect | evaluation | notes |
|--------|------------|-------|
| narrower inputs | ✓ holds | no input needed (automatic) |
| convenient | ✓ holds | zero friction for users who don't want worktopics |
| expressive | n/a | no expression needed |
| failsafes | ✓ holds | always exactly 1 worktopic minimum |
| failfasts | n/a | cannot fail |
| idempotency | ✓ holds | default state is deterministic |

### what if it failed?

if default state fails, extant cosmic users experience regression. this would block adoption.

---

## critical path 5: multi-monitor sync

**description**: all monitors switch together

**why critical**: partial switch causes confusion

### pit of success evaluation

| aspect | evaluation | notes |
|--------|------------|-------|
| narrower inputs | ✓ holds | same keybind as single-monitor |
| convenient | ✓ holds | no extra action needed |
| expressive | n/a | no expression needed |
| failsafes | **needs attention** | what if one monitor fails to switch? |
| failfasts | ✓ holds | should fail atomically (all or none) |
| idempotency | ✓ holds | deterministic |

### what if it failed?

if one monitor shows work and another shows personal, user sees mixed context. confuses and frustrates.

**action needed**: ensure atomic switch (all monitors or none). document this in criteria.

---

## issues found

| issue | severity | action taken |
|-------|----------|--------------|
| session restore should fail clearly on corruption | medium | documented for criteria update |
| multi-monitor switch should be atomic | medium | documented for criteria update |

---

## non-issues confirmed

| aspect | why it holds |
|--------|--------------|
| keybind discoverability | noted in ergonomics review; acceptable for power users |
| wrap behavior | both worktopic and workspace navigation wrap; consistent UX |
| single worktopic inert | Super+Ctrl+Tab does not surprise users who haven't configured worktopics |

---

## conclusion

critical paths are correctly identified. two minor improvements needed:
1. session restore failfast on corrupt config
2. multi-monitor atomic switch guarantee

these can be added to criteria.blueprint.md in the relevant subcomponent contracts.

