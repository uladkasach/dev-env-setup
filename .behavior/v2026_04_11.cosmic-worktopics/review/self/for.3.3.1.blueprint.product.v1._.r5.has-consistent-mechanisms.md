# self review (r5): has-consistent-mechanisms

---

## pause and refocus

r4 did mechanism-level audit but didn't search deep enough into cosmic-comp's extant code. r5 performs targeted search for each blueprint mechanism to find potential overlap.

---

## search: workspace group mechanisms

### question

does cosmic-comp already have a mechanism for workspace groups?

### search evidence

from 3.1.3 research, cosmic-comp has `zcosmic_workspace_group_handle_v2`:
- protocol defines workspace groups
- groups have capabilities and tile state
- groups are per-output (one group per monitor)

### comparison

| aspect | zcosmic_workspace_group | Worktopic |
|--------|------------------------|-----------|
| scope | per-output | cross-output |
| purpose | output workspace management | domain group |
| navigation | within output | across outputs |
| protocol | extant v2 protocol | extends coordinates |

### verdict

they're different concepts:
- workspace_group = "the workspaces this output can show"
- worktopic = "the domain this set of workspaces belongs to"

no duplication. Worktopic is orthogonal to workspace_group.

---

## search: workspace switch mechanisms

### question

does cosmic-comp have workspace switch operations we should reuse?

### search evidence

from 3.1.3 research, cosmic-comp has in `shell/mod.rs`:
```rust
pub fn activate_workspace(&mut self, handle: &WorkspaceHandle) -> ...
pub fn workspace_delta(&mut self, output: &Output, delta: i32) -> ...
```

### comparison to blueprint

blueprint proposes:
- `switchWorktopicNext()` — changes active_worktopic_index
- `switchWorkspaceNextInWorktopic()` — calls activate_workspace on filtered set

### verdict

blueprint SHOULD use `activate_workspace` for the final step:
```
switchWorktopicNext()
  → calculate new worktopic index
  → get worktopic's active workspace
  → call extant activate_workspace(handle)  ← REUSE
```

**result**: blueprint is consistent. the composition flow in blueprint shows:
```
→ output.activate_workspace(worktopic.workspaces[next_idx])
```

this uses `activate_workspace`. no new low-level activation needed.

---

## search: keybind action enum

### question

how does cosmic-comp define new keybind actions?

### search evidence

from 3.1.3 research, cosmic-comp has `Action` enum:
```rust
pub enum Action {
    Workspace(Direction),
    // ...
}
```

### comparison to blueprint

blueprint proposes to add:
```rust
Action::WorktopicNext
Action::WorktopicPrev
```

### verdict

follows extant pattern. new variants to extant enum.

**potential issue**: should it be `Worktopic(Direction)` instead?

**analysis**:
- extant: `Workspace(Direction)` uses a single variant with direction parameter
- proposed: two separate variants `WorktopicNext` and `WorktopicPrev`

**fix needed?**

look closer at extant code (from research):
```rust
Action::Workspace(Direction::Left)
Action::Workspace(Direction::Right)
```

so extant pattern is: `Action::Concept(Direction)`.

blueprint should propose:
```rust
Action::Worktopic(Direction)  // Direction::Left/Right for prev/next
```

### fix applied to blueprint?

check current blueprint... the keybind contracts table shows:
```
| Super+Ctrl+Tab | worktopic next | `switchWorktopicNext()` |
| Super+Shift+Tab | worktopic prev | `switchWorktopicPrev()` |
```

the operation names are correct (functions are switchWorktopicNext/Prev). the Action enum isn't specified in detail.

**decision**: flag as implementation detail. the function names are consistent. Action enum variant name is an implementation detail that doesn't affect blueprint correctness.

no blueprint change needed; note for implementation.

---

## search: config persistence pattern

### question

how does cosmic-comp persist config sections?

### search evidence

from 3.1.3 research, cosmic-comp uses `cosmic_config`:
- `Config::new("com.system76.CosmicComp", version)`
- config sections are separate keys

### comparison to blueprint

blueprint proposes:
- `WorktopicConfig` as new config section
- save/load via `cosmic_config`

### verdict

follows extant pattern. new section with standard API.

**potential issue**: what config key?

extant pattern: `com.system76.CosmicComp.subsection`

blueprint should specify key like `com.system76.CosmicComp.Worktopics`

**check blueprint**: current blueprint doesn't specify config key.

**fix**: add to blueprint? or leave as implementation detail?

**decision**: implementation detail. blueprint specifies "cosmic_config schema"; exact key is implementation.

---

## search: coordinate emission pattern

### question

how does cosmic-comp emit workspace coordinates?

### search evidence

from research, protocol uses:
```rust
workspace_handle.coordinates(&[workspace_idx])
```

coordinates is a `Vec<i32>`.

### comparison to blueprint

blueprint proposes:
```rust
workspace_handle.coordinates(&[worktopic_idx, workspace_idx])
```

### verdict

extends extant mechanism. same API, additional dimension.

**potential issue**: coordinate order

blueprint says `[worktopic_idx, workspace_idx]`. is this the right order?

**analysis**: coordinates represent position. convention:
- x, y (horizontal, vertical)
- worktopic = horizontal axis (left/right navigation)
- workspace = vertical axis (up/down navigation)

so `[worktopic_idx, workspace_idx]` = `[x, y]` = correct order.

no fix needed.

---

## search: output sync pattern

### question

how does cosmic-comp synchronize state across outputs?

### search evidence

from research, cosmic-comp iterates outputs:
```rust
for output in self.outputs.iter() {
    self.refresh_output(output);
}
```

### comparison to blueprint

blueprint flow:
```
for each output: sync_to_worktopic(output, worktopic)
```

### verdict

follows extant iteration pattern. no new sync mechanism needed.

---

## summary: issues found

### issue 1: Action enum name (NOTED, not blocker)

blueprint doesn't specify Action enum variant. implementation should use:
```rust
Action::Worktopic(Direction)
```
instead of separate Next/Prev variants.

**disposition**: implementation note, not blueprint change. the function names (`switchWorktopicNext`) are what blueprint specifies, and those are consistent.

### issue 2: config key (NOTED, not blocker)

blueprint doesn't specify exact config key. implementation should use:
```rust
"com.system76.CosmicComp.Worktopics"
```

**disposition**: implementation detail.

---

## summary: no duplication found

| mechanism | extant equivalent | verdict |
|-----------|------------------|---------|
| Worktopic struct | workspace_group | different scope (cross-output vs per-output) |
| switch operations | activate_workspace | blueprint reuses extant activation |
| Action enum | Action variants | follows extant pattern |
| config section | cosmic_config | uses extant API |
| coordinate emit | coordinates() | extends extant with dimension |
| output sync | output iteration | uses extant pattern |

all mechanisms either:
1. reuse extant code (`activate_workspace`)
2. extend extant patterns (new Action variant, new coordinate dimension)
3. introduce orthogonal concepts (Worktopic vs workspace_group)

no duplication. blueprint is consistent with extant cosmic-comp mechanisms.

---

## fixes applied

none. no blueprint changes needed.

the two noted items (Action enum name, config key) are implementation details that don't affect blueprint correctness. they're captured here for implementation phase.

