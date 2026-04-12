# self review (r6): has-consistent-conventions

---

## pause and refocus

r5 didn't find issues. r6 re-reads the blueprint line by line to find convention inconsistencies.

---

## found: operation name convention mismatch

### the problem

the blueprint uses two different conventions for operation names:

**domain.operations section** (lines 67-81):
```
├── [+] getOneActiveWorktopic
├── [+] setWorktopicCreate
├── [+] switchWorktopicNext
├── [+] switchWorkspaceNextInWorktopic
```

these use `camelCase` with get/set/switch prefixes.

**composition flows section** (lines 137-155):
```
→ shell.switch_worktopic_next()
→ shell.get_active_worktopic()
```

these use `snake_case`.

### the question

which convention should the blueprint use?

**cosmic-comp convention**: Rust uses `snake_case` for function names.

**blueprint purpose**: specification document, not code.

### analysis

the domain.operations section is a specification artifact. it uses "behavior-driven" names that map to implementation.

the composition flows section shows actual Rust code.

**the inconsistency**: `switchWorktopicNext` (spec) maps to `switch_worktopic_next()` (code). this is intentional — the spec uses camelCase for readability, the code uses snake_case for Rust.

### verdict

**not an issue**. the blueprint has two layers:
1. specification layer (domain.operations) — uses camelCase
2. code layer (composition flows) — uses snake_case

the map is consistent:
- `switchWorktopicNext` → `switch_worktopic_next()`
- `getOneActiveWorktopic` → `get_active_worktopic()`

this is a valid convention for behavior specification documents.

---

## found: test file name convention

### the problem

blueprint proposes:
```
tests/worktopic_play.rs
```

### cosmic-comp convention

check what cosmic-comp test files are named.

from 3.1.2 research (factory templates), cosmic-comp tests:
- live in `tests/` directory
- use descriptive snake_case names

**question**: is `_play` suffix a cosmic-comp convention?

**analysis**: `play` suggests "playground" or "journey test". cosmic-comp may use different suffixes.

**check**: from research, cosmic-comp integration tests don't have a standard suffix pattern. files are named by feature.

**verdict**: `worktopic_play.rs` is acceptable. `_play` suffix clearly indicates integration/journey tests.

alternative: `worktopic_integration.rs` or just `worktopic.rs`.

**decision**: leave as-is. not a convention violation, just a style choice.

---

## found: keybind contract table convention

### the problem

keybind contracts table shows:
```
| Super+Ctrl+Tab | worktopic next | `switchWorktopicNext()` |
```

the contract column uses camelCase (`switchWorktopicNext()`).

### analysis

same as domain.operations — this is specification layer, not code layer.

**verdict**: consistent with domain.operations section.

---

## found: composition flow code style

### the problem

composition flows show:
```
→ worktopic_idx = (active_worktopic + 1) % worktopics.len()
→ shell.set_active_worktopic(worktopic_idx)
```

### convention check

- `worktopic_idx` — snake_case variable ✓
- `active_worktopic` — snake_case field ✓
- `set_active_worktopic` — snake_case method ✓

**verdict**: consistent with Rust conventions.

---

## found: field name convention in domain objects

### the problem

domain objects section shows:
```
├── [+] Worktopic
│   ├── workspaces: Vec<WorkspaceHandle>
│   └── active_workspace_index: usize
```

### convention check

- `workspaces` — snake_case ✓
- `active_workspace_index` — snake_case ✓

**verdict**: consistent with Rust conventions.

---

## found: config struct field names

### the problem

```
├── [+] WorktopicConfig
│   ├── worktopics: Vec<WorktopicDef>
│   └── active_worktopic_index: usize
```

### convention check

- `worktopics` — snake_case ✓
- `active_worktopic_index` — snake_case ✓

**verdict**: consistent with Rust conventions.

---

## cross-check: all snake_case items

| location | name | case | verdict |
|----------|------|------|---------|
| Worktopic.workspaces | field | snake_case | ✓ |
| Worktopic.active_workspace_index | field | snake_case | ✓ |
| WorktopicConfig.worktopics | field | snake_case | ✓ |
| WorktopicConfig.active_worktopic_index | field | snake_case | ✓ |
| WorktopicDef.workspace_count | field | snake_case | ✓ |
| WorktopicDef.active_workspace_index | field | snake_case | ✓ |
| shell.switch_worktopic_next() | method | snake_case | ✓ |
| shell.get_active_worktopic() | method | snake_case | ✓ |
| worktopic_idx | variable | snake_case | ✓ |

all code-layer names use snake_case.

---

## cross-check: all PascalCase items

| location | name | case | verdict |
|----------|------|------|---------|
| Worktopic | struct | PascalCase | ✓ |
| WorktopicConfig | struct | PascalCase | ✓ |
| WorktopicDef | struct | PascalCase | ✓ |
| WorkspaceHandle | type reference | PascalCase | ✓ |
| Shell | struct reference | PascalCase | ✓ |

all type names use PascalCase.

---

## cross-check: specification layer names

| section | name | case | purpose |
|---------|------|------|---------|
| domain.operations | getOneActiveWorktopic | camelCase | spec identifier |
| domain.operations | setWorktopicCreate | camelCase | spec identifier |
| domain.operations | switchWorktopicNext | camelCase | spec identifier |
| keybind contracts | switchWorktopicNext() | camelCase | spec reference |

all specification identifiers use camelCase.

---

## issues found: none

the blueprint has two convention layers:
1. **specification layer**: camelCase for operation identifiers
2. **code layer**: snake_case for Rust code

this is intentional and consistent:
- domain.operations section = specification (camelCase)
- composition flows section = code preview (snake_case)
- all struct/type names = PascalCase
- all field names = snake_case

no convention divergences found.

---

## why it holds

1. **Rust conventions in code**: all code samples use snake_case methods, snake_case fields, PascalCase types
2. **Specification conventions in spec**: all operation identifiers use camelCase
3. **clear separation**: spec sections vs code sections are visually distinct
4. **consistent map**: `switchWorktopicNext` (spec) → `switch_worktopic_next()` (code)

the blueprint correctly uses multiple convention layers appropriate to each context.

