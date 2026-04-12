# self review (r9): has-role-standards-coverage

---

## the question

are all relevant mechanic standards applied?
are there patterns that should be present but are absent?

---

## rule directories checked for coverage

| directory | coverage check |
|-----------|----------------|
| code.prod/pitofsuccess.errors | fail-fast, error handle |
| code.prod/pitofsuccess.procedures | idempotency, validation |
| code.prod/evolvable.procedures | input-context pattern |
| code.test | test coverage |

---

## error handle coverage

### rule.require.fail-fast

| operation | precondition | error path |
|-----------|--------------|------------|
| switchWorktopicNext | worktopics.len() >= 1 | invariant 1 guarantees >= 1, no error path needed |
| setWorktopicDelete | worktopics.len() > 1 | test_worktopic_delete_last_blocked verifies this |
| saveWorktopicConfig | shell initialized | precondition from startup flow |
| loadWorktopicConfig | cosmic_config available | fallback to default (line 176) |

**why it holds**: invariants enforce preconditions. persistence flow shows explicit fallback.

### config corruption error path

blueprint line 275: "session restore corruption | validate config on load, fallback to default"

the risks section explicitly addresses corruption with fallback strategy.

**verdict**: error handle covered.

---

## idempotency coverage

### rule.require.idempotent-procedures

| operation | idempotent? | reason |
|-----------|-------------|--------|
| switchWorktopicNext | yes | sets index to computed value |
| switchWorktopicPrev | yes | sets index to computed value |
| switchWorkspaceNextInWorktopic | yes | activates workspace by reference |
| saveWorktopicConfig | yes | overwrites config file |
| loadWorktopicConfig | yes | reads config, applies state |
| setWorktopicCreate | depends | if creates duplicate, no; if unique, yes |
| setWorktopicDelete | yes | delete is idempotent (no-op if absent) |

**gap found**: `setWorktopicCreate` idempotency not specified.

**analysis**: this is a spec document. implementation will define whether duplicate create throws or is no-op.

**verdict**: note for implementation. not a blocker for spec.

---

## validation coverage

### input validation

| operation | input | validation needed |
|-----------|-------|-------------------|
| switchWorktopicNext | none | no input to validate |
| setActiveWorktopic | worktopic_idx | must be < worktopics.len() |
| setWorktopicDelete | worktopic_id | must exist, must not be last |

**why it holds**: invariants (lines 220-226) specify valid index constraints:
- `active_worktopic_index < worktopics.len()` — always valid
- `worktopics.len() >= 1` — always at least 1

validation is implicit in invariant enforcement.

**verdict**: validation covered via invariants.

---

## test coverage check

### rule.require.test-covered-repairs

| behavior | test coverage |
|----------|---------------|
| worktopic switch | test_switch_navigates |
| worktopic wrap | test_switch_wraps |
| workspace nav | test_workspace_nav_stays_in_worktopic |
| delete blocked | test_worktopic_delete_last_blocked |
| persistence | test_config_round_trip |
| multi-monitor | test_all_monitors_sync |
| keybind trigger | test_keybind_triggers_switch |
| session restore | test_session_restore |

**verdict**: all behaviors have test coverage specified.

---

## type coverage check

### rule.require.domain-driven-design

| domain concept | type coverage |
|----------------|---------------|
| worktopic | Worktopic struct |
| config | WorktopicConfig struct |
| config entry | WorktopicDef struct |
| workspace reference | WorkspaceHandle (extant) |

**verdict**: all domain concepts have types.

---

## summary

| standard | coverage | notes |
|----------|----------|-------|
| fail-fast | covered | invariants + fallback |
| idempotency | mostly | setWorktopicCreate needs impl detail |
| validation | covered | via invariants |
| test coverage | covered | comprehensive |
| types | covered | DDD patterns |

---

## why it holds

1. **error handle**: invariants guarantee valid state, persistence has fallback
2. **idempotency**: most operations are naturally idempotent (state assignment)
3. **validation**: index bounds enforced via invariants
4. **tests**: every usecase has matched tests
5. **types**: all domain concepts have explicit structs

the blueprint covers all relevant mechanic standards for a specification document.

