# self review (r1): has-questioned-deletables

---

## the question

> can any component be removed entirely? did we optimize a component that should not exist?

---

## methodology

i read through the blueprint line by line. for each component, i asked:
1. can this be removed entirely?
2. if we deleted this and had to add it back, would we?
3. did we optimize a component that should not exist?
4. what is the simplest version that works?

---

## deletions found and applied

### 1. WorktopicId type — DELETED

**the questioning:**
- worktopics live in `Vec<Worktopic>`
- navigation uses indices: `(active + 1) % len`
- protocol emits indices: `[worktopic_idx, workspace_idx]`
- config stores position implicitly via Vec order

**why it should not exist:**
- a separate id only matters if we reorder worktopics (not in MVP)
- a separate id only matters if external systems reference by id (protocol uses index)
- Vec position IS the identifier; a separate id duplicates this

**cascade effects:**
- `id: WorktopicId` field in Worktopic → DELETE
- `id: u64` field in WorktopicDef → DELETE
- `getOneWorktopic` operation → DELETE (use `shell.worktopics[idx]`)

### 2. getAllWorktopics operation — DELETED

**the questioning:**
- what does it return? `shell.worktopics` (the Vec itself)
- what does the caller do? iterate or index

**why it should not exist:**
- this is field access, not an operation
- no computation, no side effects, no validation
- callers can access `shell.worktopics` directly

### 3. syncMonitorsToWorktopic — MADE INTERNAL

**the questioning:**
- who calls it? only `setActiveWorktopic`
- does it need to be public? no external callers

**why it should not be a named operation:**
- internal implementation detail of worktopic switch
- exposing it suggests callers should use it directly
- hiding it reduces API surface

### 4. WorktopicSwitchEvent — REMOVED

**the questioning:**
- what purpose does it serve? notify internal components
- who listens? no one in MVP
- how else are clients notified? protocol coordinates

**why it should not exist:**
- protocol emission already notifies wayland clients
- no internal components need this event for MVP
- add it back when a consumer exists

### 5. test consolidation — test_switch_navigates

**the questioning:**
- test_switch_next_increments tests increment
- test_switch_prev_decrements tests decrement
- these are symmetric operations

**why separate tests should not exist:**
- one test can verify both directions
- reduces test count without loss of coverage
- symmetric logic deserves symmetric verification

---

## what cannot be deleted and why

### Worktopic entity

**questioned:** can we represent worktopics without a dedicated struct?

**why it must stay:**
- core domain object; the entire feature is "worktopics"
- holds workspaces Vec and active_workspace_index
- no alternative representation exists

**if deleted and had to add back:** immediately, cannot function without it

### WorktopicConfig and WorktopicDef

**questioned:** can we inline the config schema?

**why they must stay:**
- cosmic_config requires named types for schema registration
- WorktopicDef decouples serialization from runtime (format evolution)
- if we serialize Worktopic directly, we'd serialize WorkspaceHandles (wrong)

**if deleted and had to add back:** yes, when persistence fails we'd add them

### setWorktopicCreate and setWorktopicDelete

**questioned:** MVP could use config-only creation (edit file, restart)

**why they must stay:**
- test setup requires programmatic creation/deletion
- config-file-only creation is worse UX
- low complexity cost (10-20 lines each)

**if deleted and had to add back:** yes, when tests become painful

### getOneActiveWorktopic

**questioned:** this is just `shell.worktopics[shell.active_worktopic_index]`

**why it must stay:**
- used in multiple places (workspace nav, protocol emit, UI)
- one-line convenience method prevents index errors
- semantically clearer than inline array access

**if deleted and had to add back:** probably not, but inline access is error-prone

### 4 phases

**questioned:** could phases 3 and 4 be combined?

**why they must stay separate:**
- phase 3 tests persistence (requires cosmic_config)
- phase 4 tests multi-monitor (requires multiple outputs)
- multi-monitor persistence depends on phase 3 completion
- clear gates prevent skipped validation

### 10 unit tests

**questioned:** can we reduce further?

**test-by-test analysis:**
- test_worktopic_create — essential, verifies initial state
- test_worktopic_delete_moves_windows — essential, safety invariant
- test_worktopic_delete_last_blocked — essential, prevents crash
- test_switch_navigates — essential, core navigation
- test_switch_wraps — essential, wrap behavior
- test_switch_inert_single — essential, edge case for 1 worktopic
- test_workspace_nav_stays_in_worktopic — essential, core behavior
- test_workspace_nav_wraps — essential, wrap within worktopic
- test_config_round_trip — essential, persistence contract
- test_default_state — essential, initial state contract

**no further consolidation possible.** each test covers a distinct behavioral case.

### 4 integration tests

**questioned:** can we reduce?

**test-by-test analysis:**
- test_keybind_triggers_switch — proves keybind wiring works
- test_all_monitors_sync — proves multi-monitor coordination
- test_coordinates_emit_2d — proves protocol contract
- test_session_restore — proves persistence contract

**each tests a different integration boundary.** cannot reduce.

### 5 invariants

**questioned:** are all 5 load-bearing?

**invariant-by-invariant analysis:**
- #1 (at least 1 worktopic) — prevents empty navigation
- #2 (at least 1 workspace per worktopic) — prevents empty workspace nav
- #3 (1:1 workspace:worktopic) — core design decision, prevents ambiguity
- #4 (valid worktopic index) — prevents out-of-bounds crash
- #5 (valid workspace index) — prevents out-of-bounds crash

**all are load-bearing.** removing any creates crash risk or undefined behavior.

---

## the simplest version

the blueprint after deletions represents the simplest version that:
- implements 2D workspace navigation
- persists across sessions
- emits protocol coordinates
- supports multi-monitor

**no further simplification is possible without removing features.**

---

## summary

**deleted:**
1. WorktopicId type
2. Worktopic.id field
3. WorktopicDef.id field
4. getOneWorktopic operation
5. getAllWorktopics operation
6. syncMonitorsToWorktopic (made internal)
7. WorktopicSwitchEvent
8. test_switch_next_increments (consolidated)
9. test_switch_prev_decrements (consolidated)

**kept with justification:**
- Worktopic, WorktopicConfig, WorktopicDef (core domain)
- setWorktopicCreate/Delete (test setup)
- getOneActiveWorktopic (clarity)
- 4 phases (clear gates)
- 10 unit tests (distinct cases)
- 4 integration tests (distinct boundaries)
- 5 invariants (all load-bearing)

