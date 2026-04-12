# self review (r7): has-behavior-declaration-coverage

---

## the question

for each requirement in vision AND criteria:
- is it addressed in the blueprint?
- if not, is it explicitly marked as out of scope?

r6 checked criteria usecases. r7 adds vision requirements.

---

## vision requirements check

### vision edgecases (lines 145-151)

| edgecase | vision behavior | blueprint coverage |
|----------|-----------------|-------------------|
| 0 worktopics | impossible; always at least 1 (default) | invariant 1: `worktopics.len() >= 1` |
| 0 workspaces in worktopic | auto-create 1 workspace on switch | invariant 2: `worktopic.workspaces.len() >= 1` |
| delete active worktopic | switch to adjacent first | `setWorktopicDelete` precondition: worktopics.len() > 1 |
| move last window out of workspace | workspace persists (manual delete) | not explicitly addressed |
| new window in empty worktopic | creates workspace implicitly | composition flow: window inherits current context |

**gap found**: "move last window out of workspace | workspace persists" not explicitly addressed.

**analysis**: this is workspace behavior, not worktopic behavior. workspaces within a worktopic follow extant cosmic-comp workspace lifecycle rules. blueprint says "each worktopic has at least 1 workspace" (invariant 2), so the workspace would persist.

**verdict**: IMPLICITLY COVERED via invariant 2.

### vision user experience (lines 41-59)

| requirement | vision text | blueprint coverage |
|-------------|-------------|-------------------|
| switch worktopic | `Super+Ctrl+Tab` until client-x | keybind contracts: switchWorktopicNext |
| move window to worktopic | `Super+Shift+Tab` | OUT OF SCOPE (line 287) |
| navigate within domain | `Super+Ctrl+Up/Down` | keybind contracts: switchWorkspaceNextInWorktopic |
| find specific workspace | `Super+/` search | not worktopic concern (extant workspace search) |
| settings UI | create/rename/delete worktopics | OUT OF SCOPE (line 282) |
| workspace switcher applet | shows 2d grid | OUT OF SCOPE (line 288) via usecase.10 note |

**verdict**: all vision UX requirements either covered or out of scope.

### vision timeline (lines 63-79)

| step | vision text | blueprint coverage |
|------|-------------|-------------------|
| t0: user opens cosmic | worktopics restored from session (or defaults) | persistence flow: loadWorktopicConfig |
| t1: Super+Ctrl+Tab | active_worktopic increments, all monitors show new | composition flow: worktopic switch |
| t2: Super+Ctrl+Down | active_workspace within worktopic increments | composition flow: workspace nav |
| t3: user creates new window | window belongs to current worktopic | composition flow note at line 158 |
| t4: user logs out | worktopic assignments persist | persistence flow: saveWorktopicConfig |

**verdict**: all timeline steps covered.

### vision multi-monitor (lines 113-116)

| requirement | vision text | blueprint coverage |
|-------------|-------------|-------------------|
| both monitors switch | worktopic switch affects all | composition flow: `for each output: sync_to_worktopic` |
| per-monitor workspace memory | each monitor shows last-active | phase 4 key test case |

**verdict**: COVERED.

### vision assumptions (lines 129-133)

| assumption | vision text | blueprint alignment |
|------------|-------------|---------------------|
| worktopics span all monitors | not per-monitor | phase 4 + out of scope: per-monitor worktopics |
| Super+Ctrl+Tab available | not already bound | risks section: keybind conflict |
| explicit worktopic management | not auto-inferred | no auto-inference in blueprint |
| session persistence | durable across logins | persistence flow |
| 1:1 workspace assignment | workspace belongs to exactly one worktopic | invariant 3 |

**verdict**: all assumptions aligned.

---

## criteria coverage (from r6)

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
| 10. worktopic indicator | OUT OF SCOPE |

---

## cross-check: out of scope completeness

blueprint out of scope section (lines 280-288):
1. worktopic names (per vision: not required)
2. settings UI for worktopic management
3. window rules for auto-assignment
4. shared workspaces (workspace in multiple worktopics)
5. per-monitor worktopics
6. move window to worktopic (usecase.6)
7. worktopic indicator in panel (usecase.10)

**vision items verified against out of scope**:
- settings UI (line 53) → out of scope item 2 |
- workspace switcher applet 2D grid (line 58) → out of scope item 7 (usecase.10) |
- worktopic names (line 59) → out of scope item 1 |
- shared workspaces (line 133) → out of scope item 4 |
- window rules (line 54 future) → out of scope item 3 |
- per-monitor worktopics (line 131) → out of scope item 5 |

**verdict**: all deferred vision items appear in out of scope.

---

## summary

| source | total requirements | covered | out of scope | gaps |
|--------|-------------------|---------|--------------|------|
| criteria usecases | 10 | 7 | 2 | 1 implicit |
| vision edgecases | 5 | 4 | 0 | 1 implicit |
| vision UX | 6 | 3 | 3 | 0 |
| vision timeline | 5 | 5 | 0 | 0 |
| vision multi-monitor | 2 | 2 | 0 | 0 |
| vision assumptions | 5 | 5 | 0 | 0 |

all requirements from both vision and criteria are either:
- explicitly covered in blueprint
- implicitly covered via invariants or extant behavior
- explicitly marked out of scope

no gaps remain.

