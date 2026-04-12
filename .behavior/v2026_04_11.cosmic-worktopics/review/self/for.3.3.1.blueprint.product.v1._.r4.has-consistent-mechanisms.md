# self review (r4): has-consistent-mechanisms

---

## the question

for each new mechanism in the blueprint:
- does cosmic-comp already have a mechanism that does this?
- do we duplicate extant utilities or patterns?
- could we reuse an extant component instead?

---

## mechanism audit: domain objects

### Worktopic struct

**what we propose:**
```rust
pub struct Worktopic {
    pub workspaces: Vec<WorkspaceHandle>,
    pub active_workspace_index: usize,
}
```

**extant patterns in cosmic-comp:**

from research (3.1.3), cosmic-comp has:
- `WorkspaceSet` — collection of workspaces per output
- `Workspace` — individual workspace entity
- `WorkspaceHandle` — reference to workspace

**does Worktopic duplicate WorkspaceSet?**

no. they serve different purposes:
- `WorkspaceSet`: per-output workspace collection (horizontal axis)
- `Worktopic`: cross-output workspace group (domain axis)

WorkspaceSet manages which workspaces an output can display. Worktopic groups workspaces by semantic domain. they're orthogonal.

**verdict**: new entity, no duplication

### WorktopicConfig / WorktopicDef

**extant patterns:**

cosmic-comp uses `cosmic_config` for persistence. research showed:
- config structs derive `Serialize, Deserialize`
- config stored in RON format
- standard pattern: `FooConfig` with `FooDef` for nested items

**do we follow the pattern?**

yes. `WorktopicConfig` with `Vec<WorktopicDef>` matches extant config patterns.

**verdict**: follows extant pattern

---

## mechanism audit: navigation operations

### switchWorktopicNext / switchWorktopicPrev

**what we propose:**

```
worktopic_idx = (active_worktopic + 1) % worktopics.len()
```

**extant patterns:**

cosmic-comp workspace navigation uses similar modular arithmetic:
```rust
// extant workspace switch pattern
let next = (current + 1) % workspaces.len();
```

**do we duplicate?**

no. we apply the same pattern to a new axis. the implementation follows extant conventions.

**verdict**: consistent with extant pattern

### switchWorkspaceNextInWorktopic / switchWorkspacePrevInWorktopic

**what we propose:**

navigate workspaces filtered to current worktopic.

**extant patterns:**

extant workspace nav operates on `WorkspaceSet`. we filter to `worktopic.workspaces` instead.

**question**: should we extend `WorkspaceSet` or create new operations?

**analysis**:
- `WorkspaceSet` is per-output
- `Worktopic` is cross-output
- they're different scopes

**verdict**: new operations justified; different scope

---

## mechanism audit: keybind dispatch

### keybind dispatch pattern

**what we propose:**

add match arms to extant keybind handler:
```rust
match action {
    // ... extant arms
    Action::WorktopicNext => shell.switch_worktopic_next(),
    Action::WorktopicPrev => shell.switch_worktopic_prev(),
}
```

**extant patterns:**

cosmic-comp keybind handler uses match-based dispatch. new keybinds add arms.

**do we follow the pattern?**

yes. we extend the extant handler, not create a new one.

**verdict**: consistent with extant pattern

---

## mechanism audit: persistence operations

### saveWorktopicConfig / loadWorktopicConfig

**what we propose:**

```rust
cosmic_config.write::<WorktopicConfig>(config)
cosmic_config.read::<WorktopicConfig>()
```

**extant patterns:**

cosmic-comp uses `cosmic_config` crate for all persistence. standard API:
- `Config::new(id, version)`
- `config.get()` / `config.set()`

**do we follow the pattern?**

yes. we use the extant `cosmic_config` API.

**question**: does cosmic-comp have a wrapper for config round-trip?

**research needed**: check if there's a standard wrapper or if direct API use is expected.

**verdict**: follows extant pattern; verify API during implementation

---

## mechanism audit: protocol emission

### 2D coordinate emission

**what we propose:**

```rust
workspace_handle.coordinates(&[worktopic_idx, workspace_idx])
```

**extant patterns:**

cosmic-comp already emits coordinates via `zcosmic_workspace_handle_v2`:
```rust
handle.coordinates(&[workspace_idx])
```

**do we duplicate?**

no. we extend the extant emission to include worktopic dimension. same API, more data.

**verdict**: extends extant mechanism

---

## mechanism audit: monitor coordination

### sync_to_worktopic

**what we propose:**

on worktopic switch, update all outputs to show new worktopic's workspaces.

**extant patterns:**

cosmic-comp has output iteration patterns:
```rust
for output in self.outputs.iter() {
    // update workspace state
}
```

**do we duplicate?**

no. we apply extant output iteration to worktopic sync.

**question**: does cosmic-comp have atomic multi-output update?

**analysis**: the flow is iterate → update each. if one fails, others may have already changed. this matches extant behavior (no transaction semantics).

**verdict**: consistent with extant pattern

---

## cross-check: research findings

from 3.1.3 research, identified extant patterns:
- `WorkspaceSet` for workspace collections
- `cosmic_config` for persistence
- `zcosmic_workspace_handle_v2` for protocol
- match-based keybind dispatch

**do blueprint mechanisms align?**

| mechanism | alignment |
|-----------|-----------|
| Worktopic struct | new entity, orthogonal to WorkspaceSet |
| config pattern | matches extant |
| navigation | follows extant modular arithmetic |
| keybind dispatch | extends extant handler |
| persistence | uses extant cosmic_config |
| protocol | extends extant coordinates |
| monitor sync | uses extant output iteration |

all mechanisms either:
- extend extant patterns, or
- introduce new concepts that don't duplicate extant functionality

---

## potential duplication flagged

### none found

no blueprint mechanism duplicates extant cosmic-comp functionality.

---

## opportunities for reuse identified

### cosmic_config wrapper

**observation**: if cosmic-comp has a standard config wrapper (e.g., `ConfigWrapper<T>`), we should use it instead of raw API.

**action**: verify during implementation; update blueprint if wrapper exists.

### output iteration utility

**observation**: if cosmic-comp has `for_each_output` or similar, use it for worktopic sync.

**action**: verify during implementation; update blueprint if utility exists.

---

## summary

### duplication check: PASS

| category | new mechanisms | duplicates extant? |
|----------|---------------|-------------------|
| domain objects | 3 | no |
| operations | 10 | no |
| keybind dispatch | 1 extension | no (extends) |
| persistence | 2 | no (uses extant) |
| protocol | 1 extension | no (extends) |

### consistency check: PASS

all new mechanisms follow extant cosmic-comp patterns:
- config structs follow `FooConfig` / `FooDef` pattern
- navigation uses modular arithmetic
- keybinds extend extant handler
- persistence uses `cosmic_config`
- protocol extends extant coordinates

### open items for implementation

1. verify if `cosmic_config` has higher-level wrapper
2. verify if output iteration has utility function

these don't affect blueprint correctness — they're implementation details.

