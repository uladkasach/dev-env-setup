# self review (r4): has-pruned-yagni

---

## pause and refocus

r3 found and fixed 3 YAGNI issues. r4 re-reads the updated blueprint with truly fresh eyes, question every remaining component.

the question for each: is this the MINIMUM required, or did we add "while we're here"?

---

## line-by-line examination

### deliverable 1: Worktopic data model

**blueprint says:** Worktopic with workspaces Vec and active_workspace_index

**minimum required?**
- workspaces Vec: yes — core purpose, must track which workspaces belong
- active_workspace_index: questioned in r2, clarified as fallback

**verdict:** minimum viable

---

### deliverable 2: navigation logic

**blueprint says:** switchWorktopicNext, switchWorktopicPrev, switchWorkspaceNextInWorktopic, switchWorkspacePrevInWorktopic

**minimum required?**
- switchWorktopicNext: usecase.1 explicitly requires Super+Ctrl+Tab
- switchWorktopicPrev: usecase.1 requires reverse navigation
- switchWorkspaceNextInWorktopic: usecase.2 explicitly requires Super+Ctrl+Down
- switchWorkspacePrevInWorktopic: usecase.2 requires reverse navigation

**question:** do we need BOTH directions, or could MVP be next-only with wrap?

**answer:** usecase.2 says "Super+Ctrl+Up" for prev. both directions are explicitly required.

**verdict:** minimum viable

---

### deliverable 3: keybind handlers

**blueprint says:** 4 keybinds mapped to 4 operations

**minimum required?**
- Super+Ctrl+Tab: explicitly in wish
- Super+Shift+Tab: vision says navigate both directions
- Super+Ctrl+Down/Up: wish says "up-and-down = workspaces within"

**verdict:** minimum viable

---

### deliverable 4: 2D coordinate emission

**blueprint says:** emit [worktopic_idx, workspace_idx] via extant protocol

**minimum required?**
- vision says "2D workspace control"
- protocol already supports N-dimensional coordinates
- clients need coordinates to show workspace state

**verdict:** minimum viable

---

### deliverable 5: session persistence

**blueprint says:** save/load via cosmic_config

**minimum required?**
- usecase.3 explicitly requires persistence across logout/login

**verdict:** minimum viable

---

## domain operations deep dive

### getOneActiveWorktopic

**purpose:** return current worktopic

**used by:** navigation flows need to know current worktopic

**alternative:** inline `shell.worktopics[shell.active_worktopic_index]`

**keep or remove?**
- single line of code
- but used in multiple places
- prevents index errors
- semantically clear

**verdict:** keep — convenience method is not YAGNI, it's clarity

---

### setWorktopicCreate

**purpose:** create new worktopic

**used by:** usecase.5, test setup, session restore (internally)

**question:** is a PUBLIC operation needed, or just internal?

**analysis:**
- session restore: needs to create worktopics from config
- tests: need to set up worktopic scenarios
- runtime: MVP has no UI for creation (config file only)

**option A:** keep public operation — tests use it, future UI uses it
**option B:** make internal — tests use fixtures, expose when UI added

**decision:** keep public. removing it would add complexity (test fixtures) without benefit. the operation is 5-10 lines.

**verdict:** keep — test requirements justify public API

---

### setWorktopicDelete

**purpose:** delete worktopic, move windows

**used by:** usecase.7

**question:** same as create — public or internal?

**analysis:** usecase.7 explicitly says "user deletes the worktopic via config"

**but:** if config-only, how does compositor delete at runtime? user would:
1. edit config
2. restart compositor
3. worktopics reconstructed from new config

**so:** setWorktopicDelete might not be needed for MVP!

**wait:** what about test scenarios that delete worktopics?

**actually:** tests could recreate compositor with different config. but that's cumbersome.

**decision:** keep public for tests. the operation is 10-20 lines with window migration.

**verdict:** keep — test requirements justify

---

### setActiveWorktopic

**purpose:** switch to specific worktopic by index

**used by:** internal (switchWorktopicNext calls it)

**question:** does it need to be public, or just internal?

**analysis:**
- switchWorktopicNext/Prev call it internally
- tests might want to set specific worktopic state
- no usecase requires direct "jump to worktopic N"

**option A:** keep public — tests use it
**option B:** make internal — tests use switchNext repeatedly

**verdict:** keep public for test ergonomics

---

### saveWorktopicConfig / loadWorktopicConfig

**purpose:** persistence

**used by:** usecase.3

**verdict:** required by criteria

---

## config schema examination

### WorktopicConfig

**fields:**
- worktopics: Vec<WorktopicDef>
- active_worktopic_index: usize

**minimum required?**
- worktopics: yes — must persist worktopic list
- active_worktopic_index: yes — usecase.3 says "restores active state"

**verdict:** minimum viable

---

### WorktopicDef

**fields:**
- workspace_count: usize
- active_workspace_index: usize

**minimum required?**
- workspace_count: yes — must recreate workspaces on load
- active_workspace_index: questioned

**deeper look at active_workspace_index:**

usecase.3 says:
> then(workspace assignments within worktopics are preserved)

this means: if user was on workspace 3 of worktopic "work", after restart they should be on workspace 3 again.

**verdict:** active_workspace_index IS required by criteria

---

## test examination

### are all 10 unit tests minimum?

| test | usecase | removable? |
|------|---------|------------|
| test_worktopic_create | usecase.5 | no |
| test_worktopic_delete_moves_windows | usecase.7 | no |
| test_worktopic_delete_last_blocked | usecase.7 invariant | no |
| test_switch_navigates | usecase.1 | no |
| test_switch_wraps | usecase.1 wrap | no |
| test_switch_inert_single | usecase.4 edge | no |
| test_workspace_nav_stays_in_worktopic | usecase.2 | no |
| test_workspace_nav_wraps | usecase.2 wrap | no |
| test_config_round_trip | usecase.3 | no |
| test_default_state | usecase.4 | no |

**could any be consolidated?**
- switch_navigates + switch_wraps: test different behaviors (increment vs wrap)
- delete_moves + delete_blocked: test different scenarios

r1 deletables already consolidated. no further consolidation possible.

**verdict:** minimum viable

---

### are all 4 integration tests minimum?

| test | usecase | removable? |
|------|---------|------------|
| test_keybind_triggers_switch | keybind contract | no |
| test_all_monitors_sync | usecase.8 | no |
| test_coordinates_emit_2d | protocol contract | no |
| test_session_restore | usecase.3 | no |

**verdict:** minimum viable

---

## phase examination

### are all 4 phases needed?

**phase 1 (data model):** yes — must have Worktopic struct before integration
**phase 2 (integration):** yes — must wire to keybinds and protocol
**phase 3 (persistence):** yes — usecase.3 requires persistence
**phase 4 (multi-monitor):** yes — usecase.8 requires multi-monitor

**question:** could phases 3 and 4 be deferred to post-MVP?

**answer:** no. both are in blackbox criteria. they are MVP requirements, not "nice to have".

**verdict:** all phases required

---

## what could still be YAGNI?

after r4 review, I see no remaining YAGNI. every component traces to:
- explicit usecase in criteria, OR
- test requirement (which supports usecase verification), OR
- internal consistency (invariant enforcement)

---

## summary

r4 review complete. no additional YAGNI found.

**fixes applied in r3:**
1. removed workspace.rs modification — not needed
2. removed WorkspaceSet filter — not used
3. added usecase.6 to out of scope — intentionally deferred

**questioned but kept:**
1. setWorktopicCreate/Delete — tests need them
2. setActiveWorktopic — test ergonomics
3. WorktopicDef.active_workspace_index — criteria requires workspace state persistence
4. all 10 unit tests — each covers distinct behavior
5. all 4 phases — all are in criteria

the blueprint after r3 fixes represents the minimum viable implementation of the blackbox criteria.

