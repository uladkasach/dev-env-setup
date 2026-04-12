# self review (r6): has-behavior-declaration-coverage

---

## the question

for each requirement in vision and criteria:
- is it addressed in the blueprint?
- if not, is it explicitly marked as out of scope?

---

## usecase coverage check

### usecase.1 = switch worktopics

| requirement | blueprint coverage |
|-------------|-------------------|
| Super+Ctrl+Tab increments worktopic | keybind contracts: `switchWorktopicNext()` ✓ |
| all monitors switch | composition flow: `for each output: sync_to_worktopic` ✓ |
| last-active workspace visible | `Worktopic.active_workspace_index` + monitor sync ✓ |
| wrap from last to first | `test_switch_wraps` test ✓ |
| Super+Shift+Tab decrements | keybind contracts: `switchWorktopicPrev()` ✓ |

**verdict**: COVERED

### usecase.2 = navigate workspaces within worktopic

| requirement | blueprint coverage |
|-------------|-------------------|
| Super+Ctrl+Down increments workspace | keybind contracts: `switchWorkspaceNextInWorktopic()` ✓ |
| worktopic unchanged | composition flow stays in worktopic ✓ |
| Super+Ctrl+Up decrements | keybind contracts: `switchWorkspacePrevInWorktopic()` ✓ |
| wrap within worktopic | `test_workspace_nav_wraps` test ✓ |

**verdict**: COVERED

### usecase.3 = session persistence

| requirement | blueprint coverage |
|-------------|-------------------|
| logout saves config | `saveWorktopicConfig` + persistence flow ✓ |
| login restores config | `loadWorktopicConfig` + persistence flow ✓ |
| workspace assignments preserved | `WorktopicDef.workspace_count` + `active_workspace_index` ✓ |

**verdict**: COVERED

### usecase.4 = default state

| requirement | blueprint coverage |
|-------------|-------------------|
| 1 default worktopic exists | persistence flow: `if None → default_worktopic()` ✓ |
| extant workspaces belong to default | mentioned in out-of-scope context, but not explicit mechanism |
| Super+Ctrl+Tab inert with 1 worktopic | `test_switch_inert_single` test ✓ |

**gap found**: no explicit mechanism for "extant workspaces belong to default worktopic" on first run.

**analysis**: on first run, `loadWorktopicConfig` returns None, so `shell.worktopics = [default_worktopic()]`. but how does `default_worktopic()` know about extant workspaces?

**question**: does `default_worktopic()` need to scan extant workspaces and assign them?

**decision**: this is implicit in the behavior. when worktopics feature is added, the shell initialization creates one worktopic and assigns all workspaces to it. the blueprint's invariant "each workspace belongs to exactly 1 worktopic" forces this.

**action**: add clarification to blueprint? or accept as implicit?

**verdict**: IMPLICITLY COVERED via invariant. add note for clarity.

### usecase.5 = create worktopic

| requirement | blueprint coverage |
|-------------|-------------------|
| worktopic added to list | `setWorktopicCreate` operation ✓ |
| begins with 1 empty workspace | `test_worktopic_create` verifies ✓ |
| appears at end of navigation | implicit (append to Vec) |

**verdict**: COVERED

### usecase.6 = move window to worktopic

| requirement | blueprint coverage |
|-------------|-------------------|
| window removed from worktopic A | — |
| window appears in worktopic B | — |

**verdict**: EXPLICITLY OUT OF SCOPE (line 287)

### usecase.7 = delete worktopic

| requirement | blueprint coverage |
|-------------|-------------------|
| windows move to default | `setWorktopicDelete` + `test_worktopic_delete_moves_windows` ✓ |
| worktopic removed from navigation | `setWorktopicDelete` operation ✓ |
| cannot delete last worktopic | `test_worktopic_delete_last_blocked` ✓ |

**verdict**: COVERED

### usecase.8 = multi-monitor behavior

| requirement | blueprint coverage |
|-------------|-------------------|
| both monitors switch | phase 4 + `test_all_monitors_sync` ✓ |
| each monitor shows last-active workspace | `sync_to_worktopic` + per-monitor memory ✓ |

**verdict**: COVERED

### usecase.9 = new window creation

| requirement | blueprint coverage |
|-------------|-------------------|
| window belongs to current worktopic/workspace | — |
| window not visible in other worktopics | — |

**gap found**: no explicit mechanism for window creation context inheritance.

**analysis**: the blueprint says "each workspace belongs to exactly 1 worktopic" (invariant 3). when a window is created, it lands on the current workspace. that workspace belongs to the current worktopic.

**question**: does the blueprint need explicit handler for new window creation?

**check blueprint**: no `createWindow` or `onWindowCreate` operation.

**analysis**: window creation is handled by extant cosmic-comp code. the worktopics feature doesn't need to intercept window creation — it just needs to ensure the workspace→worktopic assignment is maintained.

**verdict**: IMPLICITLY COVERED. new windows land on workspaces, workspaces belong to worktopics. no explicit mechanism needed.

### usecase.10 = worktopic indicator

| requirement | blueprint coverage |
|-------------|-------------------|
| worktopic index visible in panel | — |
| indicator updates on switch | — |

**gap found**: no blueprint mechanism for worktopic indicator.

**analysis**: the blueprint's out-of-scope section doesn't mention indicator. the vision mentions:
> "worktopic index is visible in panel"

but the blueprint doesn't address this.

**question**: is indicator part of cosmic-comp or cosmic-workspaces-epoch (applet)?

**from vision**:
> "worktopic name visible in panel (optional)"

and from wish:
> "just the 2d organization is the real unlock"

**decision**: indicator is UI concern for cosmic-workspaces-epoch, not cosmic-comp. the compositor emits 2D coordinates; the applet displays them.

**action**: add to out-of-scope with note that applet will handle indicator.

---

## gaps found

### gap 1: usecase.4 — default worktopic absorbs extant workspaces

**status**: implicitly covered via invariant

**action**: no change needed. invariant "each workspace belongs to exactly 1 worktopic" forces all workspaces into the single default worktopic.

### gap 2: usecase.9 — new window creation

**status**: implicitly covered

**action**: no change needed. windows land on workspaces, workspaces have worktopic assignment.

### gap 3: usecase.10 — worktopic indicator

**status**: not addressed in blueprint

**action**: ADD TO OUT OF SCOPE

**fix**: add to out-of-scope section:
```
- worktopic indicator in panel (applet concern — cosmic-workspaces-epoch will use 2D coordinates)
```

---

## fix applied to blueprint

### addition to out of scope section

**before** (line 280-287):
```
## out of scope for MVP

- worktopic names (per vision: not required)
- settings UI for worktopic management
- window rules for auto-assignment
- shared workspaces (workspace in multiple worktopics)
- per-monitor worktopics
- move window to worktopic (usecase.6 — keybind deferred; Super+Shift+Tab used for prev navigation)
```

**after**:
```
## out of scope for MVP

- worktopic names (per vision: not required)
- settings UI for worktopic management
- window rules for auto-assignment
- shared workspaces (workspace in multiple worktopics)
- per-monitor worktopics
- move window to worktopic (usecase.6 — keybind deferred; Super+Shift+Tab used for prev navigation)
- worktopic indicator in panel (usecase.10 — applet concern; cosmic-workspaces-epoch will consume 2D coordinates)
```

---

## summary

| usecase | status |
|---------|--------|
| 1. switch worktopics | COVERED |
| 2. workspace nav in worktopic | COVERED |
| 3. session persistence | COVERED |
| 4. default state | IMPLICITLY COVERED |
| 5. create worktopic | COVERED |
| 6. move window to worktopic | OUT OF SCOPE |
| 7. delete worktopic | COVERED |
| 8. multi-monitor | COVERED |
| 9. new window creation | IMPLICITLY COVERED |
| 10. worktopic indicator | OUT OF SCOPE (added) |

all criteria are either explicitly covered, implicitly covered via invariants, or explicitly marked out of scope.

