# self review (r4): has-pruned-backcompat

---

## pause and refocus

r3 found and fixed 1 speculative backcompat concern (protocol fallback). r4 performs exhaustive section-by-section audit to ensure no speculative backcompat hides in other areas.

the test: for each blueprint element, does it exist because:
- A) required for the feature to work
- B) explicitly requested by wisher
- C) speculative "compat-shield" we added defensively

only A and B pass. C must be flagged or removed.

---

## section audit: filediff tree

### `[~] mod.rs` (shell)

**what**: add worktopic module reference

**compat-check**: this is structural glue to expose the new module. no backcompat concern.

**verdict**: A (required)

### `[+] worktopic.rs`

**what**: new data model and operations

**compat-check**: new file. no extant behavior to preserve.

**verdict**: A (required)

### `[~] mod.rs` (input)

**what**: add worktopic keybind handlers

**compat-check**: extend extant handler with new match arms. extant keybinds unchanged.

**question**: do we guard against keybind collision at runtime?

**answer**: no runtime guard needed. keybinds are static config. collision check is pre-PR due diligence, not runtime backcompat.

**verdict**: A (required)

### `[~] mod.rs` (config)

**what**: add worktopic config schema

**compat-check**: extend cosmic_config with new section.

**question**: does cosmic_config require schema migration for new fields?

**answer**: cosmic_config uses RON. new fields with defaults are backwards compatible — old configs load fine (new fields get defaults). no explicit migration code needed.

**verdict**: A (required)

### `[~] workspace.rs` (protocols)

**what**: emit 2D coordinates

**compat-check**: this is where protocol fallback concern lived. r3 flagged it as OPEN QUESTION.

**verdict**: already handled in r3

---

## section audit: domain objects

### Worktopic

**fields**:
- `workspaces: Vec<WorkspaceHandle>`
- `active_workspace_index: usize`

**compat-check**: new entity. no backcompat concern.

**verdict**: A (required)

### WorktopicConfig

**fields**:
- `worktopics: Vec<WorktopicDef>`
- `active_worktopic_index: usize`

**compat-check**: persistence schema for new feature.

**question**: what happens when user upgrades from no-worktopics to worktopics?

**answer**: `loadWorktopicConfig` returns None (no saved config), and shell initializes with default (1 worktopic with all extant workspaces). this is migration, not backcompat shim.

**verdict**: A (required)

### WorktopicDef

**fields**:
- `workspace_count: usize`
- `active_workspace_index: usize`

**compat-check**: minimal fields for round-trip. no extra fields "for future use".

**verdict**: A (required)

---

## section audit: domain operations

### navigation operations

| operation | compat-check |
|-----------|-------------|
| getOneActiveWorktopic | new operation, no extant behavior |
| switchWorktopicNext | new keybind, no conflict with extant |
| switchWorktopicPrev | new keybind, no conflict with extant |
| switchWorkspaceNextInWorktopic | reuses extant workspace nav pattern |
| switchWorkspacePrevInWorktopic | reuses extant workspace nav pattern |

**question**: do workspace-in-worktopic operations break extant workspace nav?

**answer**: no. they operate on the filtered worktopic.workspaces set. extant Super+Ctrl+Up/Down behavior is separate (if it exists). blueprint proposes these as NEW keybinds, not replacements.

**verdict**: all A (required)

### lifecycle operations

| operation | compat-check |
|-----------|-------------|
| setWorktopicCreate | new operation |
| setWorktopicDelete | moves windows to default — required behavior |
| setActiveWorktopic | internal dispatch |

**question**: window move on delete — is this speculative?

**answer**: no. without this, windows would be orphaned. the behavior is necessary for delete to work.

**verdict**: all A (required)

### persistence operations

| operation | compat-check |
|-----------|-------------|
| saveWorktopicConfig | new persistence |
| loadWorktopicConfig | handles no-config case with default |

**question**: load fallback to default — is this speculative backcompat?

**answer**: no. this is first-run behavior, not old-version compat. every user starts with no config.

**verdict**: all A (required)

---

## section audit: contracts

### keybind contracts

| keybind | compat-check |
|---------|-------------|
| Super+Ctrl+Tab | new keybind |
| Super+Shift+Tab | new keybind |
| Super+Ctrl+Down | new keybind |
| Super+Ctrl+Up | new keybind |

**question**: does blueprint add fallback for if keybinds are already taken?

**answer**: no runtime fallback. risks section says "verify availability before PR". this is pre-submission due diligence, not backcompat code.

**verdict**: A (required)

### state contracts

| contract | compat-check |
|----------|-------------|
| switchWorktopicNext precondition | worktopics.len() >= 1 — invariant, not compat |
| setWorktopicDelete precondition | worktopics.len() > 1 — prevents invalid state |
| saveWorktopicConfig postcondition | writes to disk — standard |
| loadWorktopicConfig postcondition | initializes from config — standard |

**verdict**: all A (required)

### protocol contracts

**check**: emits `[worktopic_idx, workspace_idx]`

**compat-check**: r3 flagged this. the original risk "version check before 2D coords, fallback to 1D" was speculative. now marked as OPEN QUESTION.

**verdict**: already handled in r3

---

## section audit: composition flows

### worktopic switch flow

```
keybind → handler → shell.switch_worktopic_next → set_active_worktopic → sync monitors → emit coordinates
```

**compat-check**: linear flow, no defensive branches for "old behavior" or "legacy mode".

**verdict**: A (required)

### workspace navigation within worktopic flow

**compat-check**: operates on worktopic.workspaces subset. no fallback to "flat workspace list mode".

**verdict**: A (required)

### session persistence flow

**compat-check**:
- logout saves
- login loads or defaults

**question**: is the `if None → default` branch speculative backcompat?

**answer**: no. this handles first-time users and fresh installs. every installation will hit this branch once.

**verdict**: A (required)

---

## section audit: test coverage

**compat-check**: tests verify feature behavior. no tests for "compat mode" or "fallback behavior".

exception: `test_default_state` tests fresh start → 1 worktopic. this is first-run behavior, not backcompat.

**verdict**: A (required)

---

## section audit: invariants

| invariant | compat-check |
|-----------|-------------|
| worktopics.len() >= 1 | prevents empty state, not compat |
| worktopic.workspaces.len() >= 1 | prevents empty worktopic |
| 1:1 workspace:worktopic | design constraint |
| valid indices | consistency, not compat |

**verdict**: all A (required)

---

## section audit: risks and mitigations

| risk | mitigation | compat-check |
|------|------------|-------------|
| keybind conflict | verify before PR | due diligence, not runtime compat |
| keybind semantics | clarify with upstream | clarification, not compat |
| protocol breaks clients | OPEN QUESTION | flagged in r3 |
| session restore corruption | validate, fallback to default | robustness, not compat |
| multi-monitor desync | atomic switch | correctness, not compat |

**verdict**: only protocol concern was speculative; already flagged.

---

## section audit: out of scope

**compat-check**: out-of-scope items are future work, not backcompat.

**verdict**: no compat concern

---

## section audit: phase breakdown

**compat-check**: phases organize implementation. no "compat phases" or "migration phases".

**question**: should there be a migration phase for users with pre-worktopic configs?

**answer**: handled by loadWorktopicConfig returning None → default. no separate migration phase needed.

**verdict**: A (required)

---

## exhaustive summary

### backcompat concerns found in r3

| concern | disposition |
|---------|-------------|
| protocol 1D fallback | flagged as OPEN QUESTION |

### backcompat concerns found in r4

none. r4 audit found:
- 0 additional speculative backcompat
- 0 "compat mode" code paths
- 0 "legacy fallback" branches
- 0 version-check guards

### items verified as required (not compat)

| category | count | notes |
|----------|-------|-------|
| file changes | 5 | all structural |
| domain objects | 3 | new entities |
| domain operations | 10 | new operations |
| keybinds | 4 | new binds |
| invariants | 5 | consistency |
| tests | 14 | feature verification |

### what could be mistaken for backcompat but isn't

| item | why it's not backcompat |
|------|------------------------|
| loadWorktopicConfig default | first-run behavior |
| setWorktopicDelete moves windows | required for delete to work |
| config validation fallback | robustness (crash prevention) |
| keybind availability check | pre-PR due diligence |
| default worktopic absorbs workspaces | migration path for upgrade |

---

## conclusion

r4 exhaustive audit complete.

**backcompat pruned in r3**: protocol 1D fallback (marked OPEN QUESTION)

**backcompat found in r4**: none

the blueprint contains no speculative backwards-compat code beyond what r3 already flagged. all elements trace to feature requirements, not defensive "just in case" compat shims.

