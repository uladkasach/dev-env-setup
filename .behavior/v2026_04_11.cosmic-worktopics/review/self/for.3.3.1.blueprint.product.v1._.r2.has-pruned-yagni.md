# self review (r2): has-pruned-yagni

---

## methodology

for each component in the blueprint, ask:
1. was this explicitly requested in vision or criteria?
2. is this the minimum viable way to satisfy the requirement?
3. did we add abstraction "for future flexibility"?
4. did we add features "while we're here"?
5. did we optimize before we knew it was needed?

---

## domain objects examined

### Worktopic struct

**vision says:** "group workspaces by domain"

**blueprint defines:**
```
Worktopic
├── workspaces: Vec<WorkspaceHandle>
└── active_workspace_index: usize
```

**is this minimum viable?**
- workspaces: required — core purpose
- active_workspace_index: required — fallback for outputs without history

**verdict:** no YAGNI; both fields serve explicit requirements

---

### WorktopicConfig struct

**criteria says (usecase.3):** session persistence

**blueprint defines:**
```
WorktopicConfig
├── worktopics: Vec<WorktopicDef>
└── active_worktopic_index: usize
```

**is this minimum viable?**
- worktopics: required — persistence
- active_worktopic_index: required — restore active state

**verdict:** no YAGNI

---

### WorktopicDef struct

**blueprint defines:**
```
WorktopicDef
├── workspace_count: usize
└── active_workspace_index: usize
```

**is this minimum viable?**
- workspace_count: required — recreate workspaces on load
- active_workspace_index: required — restore fallback state

**verdict:** no YAGNI

---

## domain operations examined

### navigation operations

| operation | vision/criteria source | YAGNI? |
|-----------|----------------------|--------|
| getOneActiveWorktopic | needed for navigation flow | no |
| switchWorktopicNext | usecase.1: Super+Ctrl+Tab | no |
| switchWorktopicPrev | usecase.1: Super+Shift+Tab | no |
| switchWorkspaceNextInWorktopic | usecase.2: Super+Ctrl+Down | no |
| switchWorkspacePrevInWorktopic | usecase.2: Super+Ctrl+Up | no |

**verdict:** all operations map to explicit usecases

---

### lifecycle operations

| operation | vision/criteria source | YAGNI? |
|-----------|----------------------|--------|
| setWorktopicCreate | usecase.5: create worktopic | no |
| setWorktopicDelete | usecase.7: delete worktopic | no |
| setActiveWorktopic | internal: used by switch | no |

**question:** is setActiveWorktopic needed as public API?

**answer:** switchWorktopicNext internally calls setActiveWorktopic. it could be private/internal. but tests need to set specific worktopic state.

**decision:** keep as testability requirement, not YAGNI

---

### persistence operations

| operation | vision/criteria source | YAGNI? |
|-----------|----------------------|--------|
| saveWorktopicConfig | usecase.3: logout persistence | no |
| loadWorktopicConfig | usecase.3: login restore | no |

**verdict:** no YAGNI

---

## keybind contracts examined

| keybind | source |
|---------|--------|
| Super+Ctrl+Tab | wish: "super-tab for example to rotate" |
| Super+Shift+Tab | vision: navigate both directions |
| Super+Ctrl+Down | wish: "up-and-down = workspaces within" |
| Super+Ctrl+Up | wish: "up-and-down = workspaces within" |

**question:** did we add keybinds "while we're here"?

**answer:** no. all four keybinds map to explicit navigation requirements.

**verdict:** no YAGNI

---

## invariants examined

| invariant | source | YAGNI? |
|-----------|--------|--------|
| worktopics.len() >= 1 | usecase.7: cannot delete last | no |
| worktopic.workspaces.len() >= 1 | usecase.5: begins with 1 workspace | no |
| 1:1 workspace:worktopic | criteria.blueprint: single ownership | no |
| valid worktopic_index | internal consistency | no |
| valid workspace_index | internal consistency | no |

**verdict:** all invariants derive from usecases or internal consistency

---

## test coverage examined

### unit tests

| test | source | YAGNI? |
|------|--------|--------|
| test_worktopic_create | usecase.5 | no |
| test_worktopic_delete_moves_windows | usecase.7 | no |
| test_worktopic_delete_last_blocked | usecase.7 edge case | no |
| test_switch_navigates | usecase.1 | no |
| test_switch_wraps | usecase.1: wrap behavior | no |
| test_switch_inert_single | usecase.4: default state | no |
| test_workspace_nav_stays_in_worktopic | usecase.2 | no |
| test_workspace_nav_wraps | usecase.2: wrap | no |
| test_config_round_trip | usecase.3 | no |
| test_default_state | usecase.4 | no |

**question:** are 10 unit tests minimum viable?

**answer:** each test covers a distinct behavioral case. consolidation was already done in r1 deletables review.

**verdict:** no YAGNI; tests are appropriate coverage

---

### integration tests

| test | source | YAGNI? |
|------|--------|--------|
| test_keybind_triggers_switch | keybind contract | no |
| test_all_monitors_sync | usecase.8: multi-monitor | no |
| test_coordinates_emit_2d | protocol contract | no |
| test_session_restore | usecase.3 | no |

**verdict:** no YAGNI

---

## phases examined

### phase 1: data model

**is this minimum scope?**
- Worktopic struct: required
- unit tests: required for confidence

**verdict:** no YAGNI

### phase 2: integration

**is this minimum scope?**
- add worktopics to Shell: required
- keybind handlers: required
- 2D coordinates: required

**verdict:** no YAGNI

### phase 3: persistence

**is this minimum scope?**
- config schema: required
- save/load: required

**verdict:** no YAGNI

### phase 4: multi-monitor

**is this minimum scope?**
- multi-output coordination: required
- test case: required

**question:** should multi-monitor be deferred to post-MVP?

**criteria says (usecase.8):** multi-monitor is in scope

**verdict:** phase 4 is required, not YAGNI

---

## "while we're here" check

### worktopic names

**vision says:** "not required for MVP"

**blueprint says:** out of scope

**verdict:** correctly excluded

### window rules

**vision says:** "(future) window rules"

**blueprint says:** out of scope

**verdict:** correctly excluded

### settings UI

**vision says:** "settings UI → create/rename/delete"

**blueprint says:** out of scope for MVP

**verdict:** correctly excluded — compositor-only MVP

### shared workspaces

**vision says:** out of scope

**blueprint says:** out of scope

**verdict:** correctly excluded

---

## "for future flexibility" check

### extensibility points

**question:** did we add hooks or interfaces "for later"?

**answer:** no. blueprint defines concrete types and operations. no abstract interfaces, plugin hooks, or extension points.

**verdict:** no premature abstraction

### generalization

**question:** did we generalize beyond requirements?

**answer:** no. coordinates are specifically [worktopic_idx, workspace_idx], not arbitrary N-dimensional.

**verdict:** no over-generalization

---

## "optimize before needed" check

### performance

**question:** did we add cache, pool, or optimization?

**answer:** no. blueprint uses simple Vec, direct access. no performance optimization mentioned.

**verdict:** no premature optimization

### event aggregation

**question:** did we add batch for protocol events?

**answer:** no. immediate emission per change. batch was considered in assumptions review but rejected as unnecessary.

**verdict:** correct decision; no optimization needed

---

## summary

YAGNI audit complete. no violations found.

all components trace to explicit requirements:
- domain objects: minimum fields for worktopic management
- operations: map 1:1 to usecases
- keybinds: map to navigation requirements
- invariants: derive from usecases or consistency
- tests: one per behavioral case
- phases: all required; none deferred incorrectly

correctly excluded:
- worktopic names
- window rules
- settings UI
- shared workspaces

no premature:
- abstraction (no interfaces "for flexibility")
- generalization (specific 2D, not N-dimensional)
- optimization (no cache or aggregation)

