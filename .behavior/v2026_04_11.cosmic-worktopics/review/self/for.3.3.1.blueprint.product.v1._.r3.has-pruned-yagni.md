# self review (r3): has-pruned-yagni

---

## deeper examination

r2 said "no YAGNI violations" too quickly. r3 re-reads the blueprint line by line with fresh eyes.

---

## issue found: WorkspaceSet filter method

### the blueprint says

```
extant.codepaths/
├── [○] WorkspaceSet                       # retain: workspace collection
│   └── [~] methods                        # extend: filter by worktopic
```

### is this required?

look at the composition flows:

```
→ worktopic = shell.get_active_worktopic()
→ worktopic.workspaces.index_of(current_ws)
→ output.activate_workspace(worktopic.workspaces[next_idx])
```

navigation uses `worktopic.workspaces` directly. it doesn't call `WorkspaceSet.filter_by_worktopic()`.

### why it was added

probably "while we're here" — if WorkspaceSet exists, we might want to filter it.

### why it's YAGNI

1. the composition flow doesn't use it
2. the Worktopic struct already holds its workspaces
3. filter at WorkspaceSet duplicates information
4. no usecase requires filter at WorkspaceSet level

### fix

remove from blueprint:

```
extant.codepaths/
├── [○] WorkspaceSet                       # retain: workspace collection
```

no extend needed. WorkspaceSet remains unchanged.

---

## issue found: workspace.rs modification

### the blueprint says

```
src/shell/
├── [~] workspace.rs               # extend: add worktopic membership
```

### is this required?

worktopic membership is represented by `Worktopic.workspaces: Vec<WorkspaceHandle>`.

does the Workspace struct need a backpointer to its worktopic?

### check the flows

navigation flow:
```
→ worktopic = shell.get_active_worktopic()
→ current_ws = output.active_workspace
→ current_idx = worktopic.workspaces.index_of(current_ws)
```

we look up the workspace IN the worktopic's list. we don't ask the workspace "what worktopic are you in?".

### why it might be needed

if we need to answer "which worktopic does this workspace belong to?" frequently, a backpointer is efficient.

### usecases that need this

- usecase.6: move window to worktopic — need to know current worktopic
- usecase.9: new window creation — inherits current worktopic

but both can use `shell.active_worktopic` — we always know the CURRENT worktopic. we don't need to ask a workspace what worktopic it belongs to.

### conclusion

backpointer might be useful but isn't required by MVP flows. we can always scan worktopics to find which one contains a workspace if needed (rare operation).

### decision

keep the modification but clarify purpose:

```
src/shell/
├── [~] workspace.rs               # extend: add worktopic membership (optional backpointer, defer if not needed)
```

or just remove it — minimal approach is to use Worktopic.workspaces as source of truth.

### fix

remove from filediff tree. workspace.rs doesn't need modification for MVP.

---

## issue found: extant codepaths section length

### the section

```
extant.codepaths/
├── [○] Shell
│   └── [~] fields                         # extend: add worktopics Vec
├── [○] WorkspaceSet
│   └── [~] methods                        # extend: filter by worktopic
├── [○] Workspace
├── [○] keybind_handler
│   └── [~] match arms                     # extend: add worktopic actions
├── [○] cosmic_config
│   └── [~] schema                         # extend: add worktopic section
└── [○] workspace_protocol
    └── [~] coordinate_emit                # extend: emit [worktopic, workspace]
```

### minimum required

- Shell.fields: yes, must hold worktopics
- WorkspaceSet: no changes (per above)
- Workspace: no changes (per above)
- keybind_handler: yes, must dispatch to worktopic actions
- cosmic_config: yes, must persist worktopics
- workspace_protocol: yes, must emit 2D coordinates

### fix

remove unchanged codepaths from list — they're noise:

```
extant.codepaths/
├── [○] Shell
│   └── [~] fields                         # extend: add worktopics Vec
├── [○] keybind_handler
│   └── [~] match arms                     # extend: add worktopic actions
├── [○] cosmic_config
│   └── [~] schema                         # extend: add worktopic section
└── [○] workspace_protocol
    └── [~] coordinate_emit                # extend: emit [worktopic, workspace]
```

---

## re-examination: usecase.6 (move window to worktopic)

### the blackbox criteria says

```
# usecase.6 = move window to worktopic

given(user has a window in worktopic A)
  when(user moves window to worktopic B)
    then(window is removed from worktopic A)
    then(window appears in worktopic B's active workspace)
```

### the blueprint says

out of scope section doesn't mention this. but domain operations don't include `moveWindowToWorktopic`.

### is this YAGNI or MISSING?

the assumptions review flagged this:
> Super+Shift+Tab might be "move window" not "worktopic prev"
> decision: stick with prev for MVP

so it's intentionally deferred. but the criteria says it's required.

### resolution

this is a criteria vs design decision conflict. options:

1. update criteria to mark usecase.6 as deferred
2. add moveWindowToWorktopic to MVP

the vision says:
> `Super+Shift+Tab` — move current window to next worktopic

this IS in the vision. the decision to defer was made in assumptions review but the criteria wasn't updated.

### recommendation

either:
- add moveWindowToWorktopic operation (not YAGNI — it's requested)
- or explicitly add to "out of scope" section and flag for wisher decision

this is not YAGNI — it's the opposite: potentially MISSING.

---

## re-examination: test count

### r2 said 10 unit tests, 4 integration tests is minimum

### deeper look

are all tests necessary? let me check each:

| test | distinct behavior | remove? |
|------|-------------------|---------|
| test_worktopic_create | creation with 1 workspace | keep |
| test_worktopic_delete_moves_windows | window migration on delete | keep |
| test_worktopic_delete_last_blocked | invariant enforcement | keep |
| test_switch_navigates | basic navigation | keep |
| test_switch_wraps | wrap behavior | keep |
| test_switch_inert_single | single-worktopic edge case | keep |
| test_workspace_nav_stays_in_worktopic | boundary enforcement | keep |
| test_workspace_nav_wraps | wrap within worktopic | keep |
| test_config_round_trip | persistence | keep |
| test_default_state | initial state | keep |

each tests a distinct behavior. consolidation already done in r1.

### verdict

test count is minimum viable. no YAGNI.

---

## re-examination: 5 invariants

### are all necessary?

| invariant | what breaks if violated | keep? |
|-----------|-------------------------|-------|
| worktopics.len() >= 1 | empty state causes crash | keep |
| worktopic.workspaces.len() >= 1 | empty worktopic unusable | keep |
| 1:1 workspace:worktopic | design decision for MVP | keep |
| valid worktopic_index | out of bounds crash | keep |
| valid workspace_index | out of bounds crash | keep |

all prevent crashes or enforce design. no YAGNI.

---

## summary

### YAGNI found and fixed

1. **WorkspaceSet filter method** — removed; navigation uses Worktopic.workspaces directly
2. **workspace.rs modification** — removed; backpointer not needed for MVP flows
3. **unchanged codepaths listed** — removed WorkspaceSet and Workspace from extant list

### NOT YAGNI but flagged

1. **usecase.6 (move window)** — in criteria but not in blueprint; either add or mark as out of scope

### confirmed minimum viable

1. domain objects: 3 structs, all required
2. domain operations: 10 operations, all required
3. keybinds: 4, all required
4. unit tests: 10, all required
5. integration tests: 4, all required
6. invariants: 5, all required
7. phases: 4, all required

---

## fixes applied to blueprint

### 1. removed `[~] workspace.rs` from filediff tree

**before:**
```
src/shell/
├── [~] mod.rs
├── [+] worktopic.rs
└── [~] workspace.rs               # extend: add worktopic membership
```

**after:**
```
src/shell/
├── [~] mod.rs
└── [+] worktopic.rs
```

**why:** backpointer not needed. worktopic membership is tracked via Worktopic.workspaces Vec.

---

### 2. removed WorkspaceSet and Workspace from extant codepaths

**before:**
```
extant.codepaths/
├── [○] Shell
│   └── [~] fields
├── [○] WorkspaceSet
│   └── [~] methods                        # extend: filter by worktopic
├── [○] Workspace
├── [○] keybind_handler
...
```

**after:**
```
extant.codepaths/
├── [○] Shell
│   └── [~] fields
├── [○] keybind_handler
...
```

**why:**
- WorkspaceSet filter: not used in composition flows; navigation uses Worktopic.workspaces directly
- Workspace: no changes needed; membership is in Worktopic, not Workspace

---

### 3. added usecase.6 to out of scope

**before:**
```
## out of scope for MVP

- worktopic names
- settings UI
- window rules
- shared workspaces
- per-monitor worktopics
```

**after:**
```
## out of scope for MVP

- worktopic names
- settings UI
- window rules
- shared workspaces
- per-monitor worktopics
- move window to worktopic (usecase.6 — keybind deferred; Super+Shift+Tab used for prev navigation)
```

**why:** usecase.6 is in blackbox criteria but was intentionally deferred in assumptions review. making this explicit prevents confusion.

---

## verification

re-read the updated blueprint. the remaining components are all necessary:

| component | required by |
|-----------|-------------|
| Worktopic struct | core data model |
| WorktopicConfig | usecase.3: persistence |
| WorktopicDef | usecase.3: persistence |
| 10 domain operations | usecases 1,2,3,4,5,7 |
| 4 keybinds | usecases 1,2 |
| Shell.fields extend | must hold worktopics |
| keybind_handler extend | must dispatch to worktopic actions |
| cosmic_config extend | must persist worktopics |
| workspace_protocol extend | must emit 2D coordinates |

no more YAGNI found after fixes applied.

