# self review (r7): has-behavior-declaration-adherance

---

## the question

does the blueprint match vision and criteria correctly?
did the junior misinterpret or deviate from the spec?

---

## vision adherance check

### keybind adherance

| vision | blueprint | adherance |
|--------|-----------|-----------|
| `Super+Ctrl+Tab` — switch worktopics | keybind contracts: `Super+Ctrl+Tab` | MATCHES |
| `Super+Shift+Tab` — move window to worktopic | keybind contracts: `Super+Shift+Tab` = worktopic prev | DEVIATION |
| `Super+Ctrl+Up/Down` — workspace within worktopic | keybind contracts: `Super+Ctrl+Down/Up` | MATCHES |

**deviation found**: vision says `Super+Shift+Tab` moves window to worktopic (line 44). blueprint uses it for `switchWorktopicPrev`.

**check out of scope**: line 287 says "move window to worktopic (usecase.6 — keybind deferred; Super+Shift+Tab used for prev navigation)"

**verdict**: deliberate deviation, documented in out of scope. blueprint chose worktopic prev over move-window for MVP. NO FIX NEEDED.

### multi-monitor adherance

| vision | blueprint | adherance |
|--------|-----------|-----------|
| all monitors switch together | composition flow: `for each output: sync_to_worktopic` | MATCHES |
| each monitor remembers last-active workspace | phase 4 key test case | MATCHES |
| worktopics span all monitors | out of scope: per-monitor worktopics | MATCHES |

**verdict**: MATCHES.

### persistence adherance

| vision | blueprint | adherance |
|--------|-----------|-----------|
| worktopics restored on login | persistence flow: `loadWorktopicConfig` | MATCHES |
| logout saves state | persistence flow: `saveWorktopicConfig` | MATCHES |
| workspace assignments preserved | `WorktopicConfig` schema includes workspace state | MATCHES |

**verdict**: MATCHES.

### default state adherance

| vision | blueprint | adherance |
|--------|-----------|-----------|
| 1 default worktopic exists | persistence flow: `default_worktopic()` | MATCHES |
| extant workspaces belong to default | invariant 3: each workspace belongs to 1 worktopic | IMPLICIT |
| Super+Ctrl+Tab inert with 1 worktopic | test: `test_switch_inert_single` | MATCHES |

**verdict**: MATCHES.

---

## criteria adherance check

### usecase.1: switch worktopics

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| Super+Ctrl+Tab increments | switchWorktopicNext | MATCHES |
| all monitors switch | composition flow | MATCHES |
| last-active workspace visible | `active_workspace_index` + sync | MATCHES |
| wrap from last to first | test: `test_switch_wraps` | MATCHES |

**verdict**: MATCHES.

### usecase.2: workspace nav in worktopic

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| Super+Ctrl+Down increments | switchWorkspaceNextInWorktopic | MATCHES |
| worktopic unchanged | composition flow stays in worktopic | MATCHES |
| wrap within worktopic | test: `test_workspace_nav_wraps` | MATCHES |

**verdict**: MATCHES.

### usecase.3: session persistence

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| logout saves | saveWorktopicConfig | MATCHES |
| login restores | loadWorktopicConfig | MATCHES |
| workspace assignments preserved | WorktopicDef.workspace_count | MATCHES |

**verdict**: MATCHES.

### usecase.4: default state

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| 1 default worktopic | persistence flow: if None → default | MATCHES |
| extant workspaces in default | implicit via invariant | MATCHES |
| Super+Ctrl+Tab inert | test_switch_inert_single | MATCHES |

**verdict**: MATCHES.

### usecase.5: create worktopic

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| worktopic added | setWorktopicCreate | MATCHES |
| begins with 1 workspace | test_worktopic_create | MATCHES |
| appears at end | implicit: append to Vec | MATCHES |

**verdict**: MATCHES.

### usecase.6: move window to worktopic

**status**: OUT OF SCOPE (line 287)

**verdict**: N/A — deliberately deferred.

### usecase.7: delete worktopic

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| windows move to default | setWorktopicDelete + test | MATCHES |
| worktopic removed | setWorktopicDelete | MATCHES |
| cannot delete last | test_worktopic_delete_last_blocked | MATCHES |

**verdict**: MATCHES.

### usecase.8: multi-monitor

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| both monitors switch | composition flow | MATCHES |
| per-monitor workspace memory | phase 4 | MATCHES |

**verdict**: MATCHES.

### usecase.9: new window creation

| criterion | blueprint | adherance |
|-----------|-----------|-----------|
| window belongs to current | composition flow note | MATCHES |
| not visible in other worktopics | implicit via assignment | MATCHES |

**verdict**: MATCHES.

### usecase.10: worktopic indicator

**status**: OUT OF SCOPE (line 288)

**verdict**: N/A — applet concern.

---

## deviation summary

| item | deviation | resolution |
|------|-----------|------------|
| Super+Shift+Tab | vision: move window; blueprint: worktopic prev | documented in out of scope |

this is the only deviation found. it is deliberate and documented.

---

## misinterpretation check

reviewed each blueprint section for potential junior misinterpretation:

| section | potential misinterpretation | actual | verdict |
|---------|----------------------------|--------|---------|
| keybind contracts | could confuse next/prev direction | Super+Ctrl+Tab = next, Super+Shift+Tab = prev | CORRECT |
| composition flow | could miss output iteration | explicitly shows `for each output` | CORRECT |
| invariants | could allow 0 worktopics | invariant 1 prevents | CORRECT |
| persistence | could miss default fallback | persistence flow shows if None branch | CORRECT |
| coordinates | could use wrong order | explicitly `[worktopic_idx, workspace_idx]` | CORRECT |

no misinterpretations found.

---

## summary

the blueprint adheres to vision and criteria correctly:
- all usecases either match or are documented out of scope
- one deliberate keybind deviation is documented
- no junior misinterpretations detected
- invariants protect against edge cases

